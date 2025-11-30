//
//  ChatCache.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.11.25.
//

import Foundation
import Observation

/// Represents a loaded chat in memory with its messages and metadata
@Observable
class LoadedChat: Identifiable {
    let id: UUID
    var messages: [Message]
    var isGenerating: Bool
    var isBeingViewed: Bool

    init(id: UUID, messages: [Message] = [], isGenerating: Bool = false, isBeingViewed: Bool = false) {
        self.id = id
        self.messages = messages
        self.isGenerating = isGenerating
        self.isBeingViewed = isBeingViewed
    }
}

/// Manages chat state and message generation for all conversations
/// This centralizes chat data so it can be accessed and modified even when not actively displayed
@Observable
class ChatCache {
    static let shared = ChatCache()

    /// All conversations (metadata only)
    var conversations: [Conversation] = []

    /// Dictionary mapping conversation IDs to their loaded chat data
    private(set) var loadedChats: [UUID: LoadedChat] = [:]

    /// Currently active/viewed conversation ID
    var activeConversationID: UUID?

    private init() {
        // Load conversations from disk on init
        do {
            try ConversationManager.initializeStorage()
            conversations = try ConversationManager.loadIndex()
        } catch {
            print("Error loading conversations: \(error)")
        }
    }

    // MARK: - Conversation Management

    /// Gets a conversation by ID
    func getConversation(for id: UUID) -> Conversation? {
        return conversations.first(where: { $0.id == id })
    }

    /// Creates a new conversation (not shown in sidebar until first message is sent)
    func createConversation(modelUsed: String = "mistralai/mistral-medium-3.1", agentUsed: UUID?) -> Conversation {
        var model = modelUsed
        if (agentUsed != nil){
            let newModel = AgentManager.getAgent(fromUUID: agentUsed!)!.model
            if newModel != nil { model = newModel! }
        }
        
        let newConversation = Conversation(
            id: UUID(),
            title: "New Conversation",
            lastInteracted: Date.now,
            modelUsed: model,
            agentUsed: agentUsed,
            isArchived: false,
            hasMessages: false
        )

        conversations.append(newConversation)
        return newConversation
    }

    /// Syncs a conversation (saves index and updates metadata)
    func syncConversation(id: UUID) {
        guard let conversation = getConversation(for: id) else { return }
        let chat = getChat(for: id)

        // Update lastModified before saving
        conversation.lastModified = Date.now

        // Save index
        do {
            try ConversationManager.saveIndex(conversations: conversations, changedConversationID: id)
        } catch {
            print("Error saving conversation index: \(error)")
        }
    }

    /// Renames a conversation
    func renameConversation(id: UUID, to newTitle: String) {
        guard let conversation = getConversation(for: id) else { return }
        conversation.title = newTitle
        conversation.lastModified = Date.now

        do {
            try ConversationManager.saveIndex(conversations: conversations, changedConversationID: id)
        } catch {
            print("Error saving renamed conversation: \(error)")
        }
    }

    /// Deletes a conversation
    func deleteConversation(id: UUID) {
        // Mark as deleted for CloudKit sync
        CloudKitSyncManager.shared.markConversationDeleted(id)

        // Unload from cache
        unloadChat(id: id)

        // Remove from array
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations.remove(at: index)
        }

        // Delete from disk
        do {
            try ConversationManager.deleteConversation(id: id)
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }

    // MARK: - Chat Loading/Unloading

    /// Loads or retrieves a chat from cache
    /// Now supports on-demand CloudKit sync for better performance and storage efficiency
    func getChat(for id: UUID) -> LoadedChat {
        if let existing = loadedChats[id] {
            // Already loaded - trigger background refresh from CloudKit
            Task {
                try? await CloudKitSyncManager.shared.pullMessages(for: id)
            }
            return existing
        }

        // Try loading from local disk cache first
        do {
            let messages = try ConversationManager.loadMessages(for: id)
            let chat = LoadedChat(id: id, messages: messages)
            loadedChats[id] = chat

            // If we have local messages, fetch any new ones from CloudKit in background
            if !messages.isEmpty {
                print("📂 Loaded \(messages.count) cached message(s) for \(id.uuidString.prefix(8))")
                Task {
                    try? await CloudKitSyncManager.shared.pullMessages(for: id)
                }
            } else {
                // Empty local cache - try pulling from CloudKit immediately
                print("📭 No local messages for \(id.uuidString.prefix(8)) - checking CloudKit")
                let chat = chat // Capture for async use
                Task {
                    try? await CloudKitSyncManager.shared.pullMessages(for: id)
                }
            }

            return chat
        } catch {
            print("⚠️ No local cache for \(id.uuidString.prefix(8)): \(error)")
            // No local cache exists - create empty chat and try CloudKit
            let chat = LoadedChat(id: id)
            loadedChats[id] = chat

            // Attempt to pull from CloudKit
            Task {
                do {
                    try await CloudKitSyncManager.shared.pullMessages(for: id)
                    print("✅ Successfully pulled messages from CloudKit for \(id.uuidString.prefix(8))")
                } catch {
                    print("❌ Failed to pull messages from CloudKit: \(error)")
                }
            }

            return chat
        }
    }

    /// Marks a chat as being actively viewed
    func setViewing(id: UUID, isViewing: Bool) {
        let chat = getChat(for: id)
        chat.isBeingViewed = isViewing

        if isViewing {
            activeConversationID = id
        } else if activeConversationID == id {
            activeConversationID = nil
        }

        // Unload chats that are no longer needed
        cleanupUnusedChats()
    }

    /// Removes chats from memory that aren't being viewed or generating
    private func cleanupUnusedChats() {
        let idsToRemove = loadedChats.filter { id, chat in
            !chat.isBeingViewed && !chat.isGenerating
        }.map { $0.key }

        for id in idsToRemove {
            loadedChats.removeValue(forKey: id)
        }
    }

    /// Forces a chat to be unloaded from memory
    func unloadChat(id: UUID) {
        guard let chat = loadedChats[id] else { return }

        // Only unload if not being viewed or generating
        if !chat.isBeingViewed && !chat.isGenerating {
            loadedChats.removeValue(forKey: id)
        }
    }

    // MARK: - Message Generation

    /// Sends a message and generates a response in the background
    /// Returns immediately, updates happen asynchronously via Observable updates
    func sendMessage(
        modelName: String,
        agent: UUID?,
        inputText: String,
        to conversationID: UUID,
        apiKey: String,
        onCompletion: (() -> Void)? = nil
    ) {
        let chat = getChat(for: conversationID)
        guard let conversation = getConversation(for: conversationID) else { return }

        // Debug: Log conversation state BEFORE any changes
        print("📨 sendMessage called for conversation \(conversationID.uuidString.prefix(8))")
        print("  Before: hasMessages=\(conversation.hasMessages), messages.count=\(chat.messages.count)")

        // If this is the first message, mark conversation as having messages
        let isChatNew = !conversation.hasMessages
        if isChatNew {
            print("  🆕 This is the FIRST message for this conversation")
            conversation.hasMessages = true
            // Save index immediately so it appears in sidebar
            do {
                try ConversationManager.saveIndex(conversations: conversations, changedConversationID: conversationID)
                print("  ✓ Index saved (hasMessages now true)")
            } catch {
                print("  ❌ Error saving conversation index: \(error)")
            }
        } else {
            print("  ↩️ Conversation already has messages (hasMessages=true)")
        }

        // Add user message
        let userMsg = Message(
            id: UUID(),
            text: inputText,
            role: .user,
            attachmentLinks: [],
            timeStamp: .now,
            lastModified: Date.now
        )
        chat.messages.append(userMsg)
        conversation.lastInteracted = Date.now
        conversation.lastModified = Date.now

        // Save user message immediately
        saveMessages(for: conversationID)
        print("  ✓ Message saved to disk (now \(chat.messages.count) total messages)")

        // Debug: Verify message was actually written to disk
        if let diskMessages = try? ConversationManager.loadMessages(for: conversationID) {
            print("  📁 Verified on disk: \(diskMessages.count) messages")
            if diskMessages.count != chat.messages.count {
                print("  ⚠️ MISMATCH: Memory has \(chat.messages.count) but disk has \(diskMessages.count)")
            }
        }

        // Start generation
        chat.isGenerating = true

        Task {
            do {
                //let service = MistralService(apiKey: apiKey)
                let service = OpenRouter(apiKey: apiKey)
                let stream = try await service.streamMessage(messages: chat.messages, modelName: modelName, agent: agent)

                // Create blank assistant message
                let assistantMsg = Message(
                    id: UUID(),
                    text: "",
                    role: .assistant,
                    modelUsed: modelName,
                    attachmentLinks: [],
                    timeStamp: .now,
                    lastModified: Date.now
                )

                await MainActor.run {
                    chat.messages.append(assistantMsg)
                }

                let assistantIndex = chat.messages.count - 1

                // Stream response chunks
                for try await chunk in stream {
                    await MainActor.run {
                        // Update message text
                        var updatedMessage = chat.messages[assistantIndex]
                        updatedMessage.text += chunk
                        updatedMessage.lastModified = Date.now
                        chat.messages[assistantIndex] = updatedMessage
                    }
                }

                // Generation complete - save and cleanup
                await MainActor.run {
                    chat.isGenerating = false

                    // Update conversation metadata
                    chat.messages[chat.messages.count - 1].timeStamp = .now
                    conversation.lastInteracted = Date.now
                    conversation.lastModified = Date.now
                    
                    saveMessages(for: conversationID)
                    syncConversation(id: conversationID)
                    onCompletion?()

                    // Clean up if chat is no longer needed
                    cleanupUnusedChats()
                }
                
                if isChatNew { try? conversation.title = await service.generateChatName(messages: chat.messages) }
                // save again to make sure it saves our chat title
                try? ConversationManager.saveIndex(conversations: conversations, changedConversationID: conversationID)

            } catch {
                await MainActor.run {
                    chat.isGenerating = false
                    print("Error generating message: \(error)")
                    cleanupUnusedChats()
                }
            }
        }
    }
    
    func sendMessageAsSystem(
        inputText: String,
        to conversationID: UUID,
        ) {
        let chat = getChat(for: conversationID)
        guard let conversation = getConversation(for: conversationID) else { return }

        // Add user message
        let userMsg = Message(
            id: UUID(),
            text: inputText,
            role: .system,
            attachmentLinks: [],
            timeStamp: .now,
            lastModified: Date.now
        )
        chat.messages.append(userMsg)
        conversation.lastInteracted = Date.now
        conversation.lastModified = Date.now

        // Save system message immediately
            if conversation.hasMessages { saveMessages(for: conversationID)}
    }

    // MARK: - Persistence

    func saveMessages(for id: UUID) {
        guard let chat = loadedChats[id] else { return }

        do {
            try ConversationManager.saveMessages(for: id, messages: chat.messages)
        } catch {
            print("Error saving messages for \(id): \(error)")
        }
    }
}
