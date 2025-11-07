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
    let uuid: UUID
    var messages: [Message]
    var isGenerating: Bool
    var isBeingViewed: Bool

    init(uuid: UUID, messages: [Message] = [], isGenerating: Bool = false, isBeingViewed: Bool = false) {
        self.uuid = uuid
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

    /// Dictionary mapping conversation UUIDs to their loaded chat data
    private(set) var loadedChats: [UUID: LoadedChat] = [:]

    /// Currently active/viewed conversation UUID
    var activeConversationUUID: UUID?

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

    /// Gets a conversation by UUID
    func getConversation(for uuid: UUID) -> Conversation? {
        return conversations.first(where: { $0.uuid == uuid })
    }

    /// Creates a new conversation
    func createConversation(modelUsed: String = "ministral-3b-latest") -> Conversation {
        let maxId = conversations.map { $0.id }.max() ?? -1
        let newConversation = Conversation(
            id: maxId + 1,
            title: "New Conversation",
            uuid: UUID(),
            lastInteracted: Date.now,
            modelUsed: modelUsed,
            isArchived: false
        )
        conversations.append(newConversation)
        return newConversation
    }

    /// Syncs a conversation (saves index and updates metadata)
    func syncConversation(uuid: UUID) {
        guard let conversation = getConversation(for: uuid) else { return }
        let chat = getChat(for: uuid)

        // Update title from first message if conversation is new
        if chat.messages.count > 0 && conversation.title == "New Conversation" {
            conversation.title = chat.messages[0].text
        }

        // Save index
        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving conversation index: \(error)")
        }
    }

    /// Renames a conversation
    func renameConversation(uuid: UUID, to newTitle: String) {
        guard let conversation = getConversation(for: uuid) else { return }
        conversation.title = newTitle

        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving renamed conversation: \(error)")
        }
    }

    /// Deletes a conversation
    func deleteConversation(uuid: UUID) {
        // Unload from cache
        unloadChat(uuid: uuid)

        // Remove from array
        if let index = conversations.firstIndex(where: { $0.uuid == uuid }) {
            conversations.remove(at: index)
        }

        // Delete from disk
        do {
            try ConversationManager.deleteConversation(uuid: uuid)
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }

    // MARK: - Chat Loading/Unloading

    /// Loads or retrieves a chat from cache
    func getChat(for uuid: UUID) -> LoadedChat {
        if let existing = loadedChats[uuid] {
            return existing
        }

        // Load from disk if not in memory
        do {
            let messages = try ConversationManager.loadMessages(for: uuid)
            let chat = LoadedChat(uuid: uuid, messages: messages)
            loadedChats[uuid] = chat
            return chat
        } catch {
            print("Error loading chat \(uuid): \(error)")
            // Return empty chat if load fails
            let chat = LoadedChat(uuid: uuid)
            loadedChats[uuid] = chat
            return chat
        }
    }

    /// Marks a chat as being actively viewed
    func setViewing(uuid: UUID, isViewing: Bool) {
        let chat = getChat(for: uuid)
        chat.isBeingViewed = isViewing

        if isViewing {
            activeConversationUUID = uuid
        } else if activeConversationUUID == uuid {
            activeConversationUUID = nil
        }

        // Unload chats that are no longer needed
        cleanupUnusedChats()
    }

    /// Removes chats from memory that aren't being viewed or generating
    private func cleanupUnusedChats() {
        let uuidsToRemove = loadedChats.filter { uuid, chat in
            !chat.isBeingViewed && !chat.isGenerating
        }.map { $0.key }

        for uuid in uuidsToRemove {
            loadedChats.removeValue(forKey: uuid)
        }
    }

    /// Forces a chat to be unloaded from memory
    func unloadChat(uuid: UUID) {
        guard let chat = loadedChats[uuid] else { return }

        // Only unload if not being viewed or generating
        if !chat.isBeingViewed && !chat.isGenerating {
            loadedChats.removeValue(forKey: uuid)
        }
    }

    // MARK: - Message Generation

    /// Sends a message and generates a response in the background
    /// Returns immediately, updates happen asynchronously via Observable updates
    func sendMessage(
        _ text: String,
        to conversationUUID: UUID,
        apiKey: String,
        onCompletion: (() -> Void)? = nil
    ) {
        let chat = getChat(for: conversationUUID)

        // Add user message
        let userMsg = Message(
            id: chat.messages.count,
            text: text,
            role: .user,
            attachmentLinks: [],
            timeStamp: .now
        )
        chat.messages.append(userMsg)

        // Save user message immediately
        saveMessages(for: conversationUUID)

        // Start generation
        chat.isGenerating = true

        Task {
            do {
                let service = MistralService(apiKey: apiKey)
                let stream = try await service.streamMessage(messages: chat.messages)

                // Create blank assistant message
                let assistantMsg = Message(
                    id: chat.messages.count,
                    text: "",
                    role: .assistant,
                    attachmentLinks: [],
                    timeStamp: .now
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
                        chat.messages[assistantIndex] = updatedMessage
                    }
                }

                // Generation complete - save and cleanup
                await MainActor.run {
                    chat.isGenerating = false

                    // Update conversation metadata
                    if let conversation = getConversation(for: conversationUUID) {
                        conversation.lastInteracted = Date.now
                    }

                    saveMessages(for: conversationUUID)
                    syncConversation(uuid: conversationUUID)
                    onCompletion?()

                    // Clean up if chat is no longer needed
                    cleanupUnusedChats()
                }

            } catch {
                await MainActor.run {
                    chat.isGenerating = false
                    print("Error generating message: \(error)")
                    cleanupUnusedChats()
                }
            }
        }
    }

    // MARK: - Persistence

    func saveMessages(for uuid: UUID) {
        guard let chat = loadedChats[uuid] else { return }

        do {
            try ConversationManager.saveMessages(for: uuid, messages: chat.messages)
        } catch {
            print("Error saving messages for \(uuid): \(error)")
        }
    }
}
