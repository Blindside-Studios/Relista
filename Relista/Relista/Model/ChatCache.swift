//
//  ChatCache.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.11.25.
//

import Foundation
import Observation
import SwiftUI
#if os(iOS)
import UIKit
#endif

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

    /// indicate loading state used in UI
    var isLoading: Bool = false
    var loadingProgress: Double = 0.0
    
    /// All conversations (metadata only)
    var conversations: [Conversation] = []

    /// Dictionary mapping conversation IDs to their loaded chat data
    private(set) var loadedChats: [UUID: LoadedChat] = [:]

    /// Currently active/viewed conversation ID
    var activeConversationID: UUID?

    /// Dictionary tracking cancellation requests for conversations
    private var cancellationFlags: [UUID: Bool] = [:]
    
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
            model = newModel
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

        // Update lastModified before saving
        conversation.lastModified = Date.now

        // Save index
        do {
            try ConversationManager.saveIndex(conversations: conversations)
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
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving renamed conversation: \(error)")
        }
    }
    
    func setArchiveStatus(id: UUID, to status: Bool){
        guard let conversation = getConversation(for: id) else { return }
        conversation.isArchived = status
        conversation.lastModified = Date.now

        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving (un)archived conversation: \(error)")
        }
    }

    /// Deletes a conversation
    func deleteConversation(id: UUID) {
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
    func getChat(for id: UUID) -> LoadedChat {
        if let existing = loadedChats[id] {
            // Already loaded - return it
            return existing
        }

        // Try loading from local disk cache first
        do {
            let messages = try ConversationManager.loadMessages(for: id)
            let chat = LoadedChat(id: id, messages: messages)
            loadedChats[id] = chat

            if !messages.isEmpty {
                print("📂 Loaded \(messages.count) cached message(s) for \(id.uuidString.prefix(8))")
            } else {
                print("📭 No local messages for \(id.uuidString.prefix(8))")
            }

            return chat
        } catch {
            print("⚠️ No local cache for \(id.uuidString.prefix(8)): \(error)")
            // No local cache exists - create empty chat
            let chat = LoadedChat(id: id)
            loadedChats[id] = chat
            return chat
        }
    }


    /// Marks a chat as being actively viewed
    func setViewing(id: UUID, isViewing: Bool) {
        getChat(for: id).isBeingViewed = isViewing

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

    /// Cancels ongoing message generation for a conversation
    /// The cleanup code (saving messages and naming chat) will still execute
    func cancelGeneration(for conversationID: UUID) {
        cancellationFlags[conversationID] = true
    }

    /// Sends a message and generates a response in the background
    /// Returns immediately, updates happen asynchronously via Observable updates
    func sendMessage(
        modelName: String,
        agent: UUID?,
        inputText: String,
        to conversationID: UUID,
        apiKey: String,
        withHapticFeedback: Bool = true,
        onCompletion: (() -> Void)? = nil,
        tools: [any ChatTool] = [],
        attachments: [(data: Data, fileExtension: String)] = []
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
            // Ensure this conversation stays as the active one and is marked as being viewed
            activeConversationID = conversationID
            chat.isBeingViewed = true
            // Save index immediately so it appears in sidebar
            do {
                try ConversationManager.saveIndex(conversations: conversations)
                print("  ✓ Index saved (hasMessages now true)")
            } catch {
                print("  ❌ Error saving conversation index: \(error)")
            }
        } else {
            print("  ↩️ Conversation already has messages (hasMessages=true)")
        }

        // Save any attached images and collect their filenames
        var attachmentLinks: [String] = []
        for attachment in attachments {
            if let filename = try? AttachmentManager.saveImage(
                attachment.data,
                fileExtension: attachment.fileExtension,
                for: conversationID) {
                attachmentLinks.append(filename)
            }
        }

        // Add user message
        let userMsg = Message(
            id: UUID(),
            text: inputText,
            role: .user,
            attachmentLinks: attachmentLinks,
            timeStamp: .now,
            lastModified: Date.now,
            conversationID: conversationID
        )
        chat.messages.append(userMsg)
        conversation.lastInteracted = Date.now
        conversation.lastModified = Date.now
        conversation.agentUsed = agent
        conversation.modelUsed = modelName

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
        cancellationFlags[conversationID] = false // Clear any previous cancellation flag

        Task {
            do {
                // Determine provider from model
                let model = ModelList.getModelFromSlug(slug: modelName)
                let stream: AsyncThrowingStream<StreamChunk, Error>

                switch model.provider {
                case .anthropic:
                    let service = Claude(apiKey: apiKey)
                    stream = try await service.streamMessage(messages: chat.messages, modelName: modelName, agent: agent, tools: tools)
                default:
                    let service = Mistral(apiKey: apiKey)
                    stream = try await service.streamMessage(messages: chat.messages, modelName: modelName, agent: agent, tools: tools)
                }

                // Create blank assistant message
                let assistantMsg = Message(
                    id: UUID(),
                    text: "",
                    role: .assistant,
                    modelUsed: modelName,
                    attachmentLinks: [],
                    timeStamp: Date.now.addingTimeInterval(0.001),
                    lastModified: Date.now,
                    conversationID: conversationID
                )

                await MainActor.run {
                    chat.messages.append(assistantMsg)
                }

                let assistantIndex = chat.messages.count - 1

                // Haptic feedback setup
                #if os(iOS)
                var chunkCount = 0
                let maxHapticChunks = 400 // Number of chunks to provide haptic feedback for
                #endif

                // Stream response chunks
                for try await chunk in stream {
                    // Check for cancellation request
                    if cancellationFlags[conversationID] == true {
                        print("🛑 Generation cancelled for \(conversationID.uuidString.prefix(8))")
                        break
                    }

                    await MainActor.run {
                        var updatedMessage = chat.messages[assistantIndex]

                        switch chunk {
                        case .thinkingChunk(let text):
                            if updatedMessage.contentBlocks == nil {
                                updatedMessage.contentBlocks = [.thinking(ThinkingBlock(text: text, isLoading: true))]
                            } else {
                                let lastIndex = updatedMessage.contentBlocks!.count - 1
                                if case .thinking(var tb) = updatedMessage.contentBlocks![lastIndex] {
                                    tb.text += text
                                    updatedMessage.contentBlocks![lastIndex] = .thinking(tb)
                                } else {
                                    updatedMessage.contentBlocks!.append(.thinking(ThinkingBlock(text: text, isLoading: true)))
                                }
                            }
                            updatedMessage.lastModified = Date.now

                        case .content(let text):
                            updatedMessage.text += text
                            updatedMessage.lastModified = Date.now

                            if updatedMessage.contentBlocks != nil {
                                let lastIndex = updatedMessage.contentBlocks!.count - 1
                                if case .thinking(var tb) = updatedMessage.contentBlocks![lastIndex] {
                                    // Thinking is done — mark complete and start a new text block
                                    tb.isLoading = false
                                    updatedMessage.contentBlocks![lastIndex] = .thinking(tb)
                                    updatedMessage.contentBlocks!.append(.text(text))
                                } else if case .text(let existing) = updatedMessage.contentBlocks![lastIndex] {
                                    updatedMessage.contentBlocks![lastIndex] = .text(existing + text)
                                } else {
                                    updatedMessage.contentBlocks!.append(.text(text))
                                }
                            }

                            // Haptic feedback with decreasing intensity
                            #if os(iOS)
                            if withHapticFeedback && chunkCount < maxHapticChunks {
                                let intensity = 0.75 - (Double(chunkCount) / Double(maxHapticChunks))
                                self.triggerHapticFeedback(intensity: intensity)
                                chunkCount += 1
                            }
                            #endif

                        case .toolUseStarted(let id, let toolName, let displayName, let icon, let inputSummary):
                            // Flush current text into a text block, then add the tool block
                            let preToolText = updatedMessage.text
                            updatedMessage.contentBlocks = [.text(preToolText),
                                .toolUse(ToolUseBlock(id: id, toolName: toolName, displayName: displayName, icon: icon, inputSummary: inputSummary, result: nil, isLoading: true))]
                            updatedMessage.lastModified = Date.now
                            print("🔧 Tool use started: \(toolName) — \(inputSummary)")

                        case .toolResultReceived(let id, let result):
                            guard var blocks = updatedMessage.contentBlocks else { break }
                            for i in blocks.indices {
                                if case .toolUse(var tb) = blocks[i], tb.id == id {
                                    tb.result = result
                                    tb.isLoading = false
                                    blocks[i] = .toolUse(tb)
                                    break
                                }
                            }
                            updatedMessage.contentBlocks = blocks
                            updatedMessage.lastModified = Date.now
                            print("📎 Tool result received for id: \(id)")

                        case .annotations(let annotations):
                            updatedMessage.annotations = annotations
                            updatedMessage.lastModified = Date.now
                            print("📎 Received \(annotations.count) annotation(s) for message")
                        }

                        chat.messages[assistantIndex] = updatedMessage
                    }
                }

                // Generation complete - save and cleanup
                await MainActor.run {
                    chat.isGenerating = false
                    cancellationFlags[conversationID] = false // Clear cancellation flag

                    // Update conversation metadata
                    let assistantMessageID = chat.messages[chat.messages.count - 1].id
                    chat.messages[chat.messages.count - 1].timeStamp = .now
                    conversation.lastInteracted = Date.now
                    conversation.lastModified = Date.now

                    saveMessages(for: conversationID)
                    syncConversation(id: conversationID)
                    onCompletion?()

                    // Clean up if chat is no longer needed
                    cleanupUnusedChats()
                }
                
                if isChatNew { try? conversation.title = await Mistral(apiKey: KeychainHelper.shared.mistralAPIKey).generateChatName(messages: chat.messages) }
                // save again to make sure it saves our chat title
                try? ConversationManager.saveIndex(conversations: conversations)
                
                #if os(iOS)
                // provide haptic feedback that message is done generating
                if withHapticFeedback {
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.success)
                }
                #endif

            } catch {
                await MainActor.run {
                    chat.isGenerating = false
                    cancellationFlags[conversationID] = false // Clear cancellation flag
                    print("Error generating message: \(error)")
                    #if os(iOS)
                    // provide haptic feedback that message failed generating
                    if withHapticFeedback {
                        let feedbackGenerator = UINotificationFeedbackGenerator()
                        feedbackGenerator.notificationOccurred(.error)
                    }
                    #endif
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
            lastModified: Date.now,
            conversationID: conversationID
        )
        chat.messages.append(userMsg)
        conversation.lastInteracted = Date.now
        conversation.lastModified = Date.now

        // Save system message immediately
        if conversation.hasMessages {
            saveMessages(for: conversationID)
        }
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

    // MARK: - Haptic Feedback

    #if os(iOS)
    /// Triggers haptic feedback with varying intensity (1.0 = strongest, 0.0 = weakest)
    private func triggerHapticFeedback(intensity: Double) {
        let clampedIntensity = max(0.0, min(1.0, intensity))

        // Map intensity to feedback style
        let impactGenerator: UIImpactFeedbackGenerator
        if clampedIntensity > 0.75 {
            impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        } else if clampedIntensity > 0.5 {
            impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        } else if clampedIntensity > 0.25 {
            impactGenerator = UIImpactFeedbackGenerator(style: .light)
        } else {
            impactGenerator = UIImpactFeedbackGenerator(style: .soft)
        }

        impactGenerator.prepare()
        impactGenerator.impactOccurred(intensity: clampedIntensity)
    }
    #endif

    // MARK: - Sync Support

    /// Update loaded conversations with refreshed data from storage
    /// Called after iCloud sync updates files
    @MainActor
    func updateLoadedConversations(_ updatedConversations: [Conversation]) {
        // Update conversations array with newest versions
        for (index, conversation) in conversations.enumerated() {
            if let updated = updatedConversations.first(where: { $0.id == conversation.id }),
               updated.lastModified > conversation.lastModified {
                conversations[index] = updated
            }
        }

        // Add any new conversations that we don't have locally
        let localIDs = Set(conversations.map { $0.id })
        let newConversations = updatedConversations.filter { !localIDs.contains($0.id) }
        conversations.append(contentsOf: newConversations)
    }
}
