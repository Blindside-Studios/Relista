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

    /// All conversations (metadata only)
    var conversations: [Conversation] = []

    /// Dictionary mapping conversation IDs to their loaded chat data
    private(set) var loadedChats: [UUID: LoadedChat] = [:]

    /// Currently active/viewed conversation ID
    var activeConversationID: UUID?

    /// Dictionary tracking cancellation requests for conversations
    private var cancellationFlags: [UUID: Bool] = [:]

    /// Set tracking conversations currently being pulled from CloudKit to prevent duplicate pulls
    private var activeCloudKitPulls: Set<UUID> = []

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
        //let chat = getChat(for: id)

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
        // Unload from cache
        unloadChat(id: id)

        // Remove from array
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations.remove(at: index)
        }

        // Delete from disk and sync to CloudKit
        do {
            try ConversationManager.deleteConversation(id: id)
            // Don't sync to CloudKit here - deleteConversation() already handles CloudKit deletion
            try ConversationManager.saveIndex(conversations: conversations, syncToCloudKit: false)
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }

    // MARK: - Chat Loading/Unloading

    /// Loads or retrieves a chat from cache
    /// Loads from local disk only - call pullMessagesIfNeeded() separately to sync from CloudKit
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

    /// Pulls messages from CloudKit for a conversation if not already pulling
    /// Safe to call multiple times - will only pull once
    func pullMessagesIfNeeded(for id: UUID) {
        guard !activeCloudKitPulls.contains(id) else {
            return // Already pulling
        }

        activeCloudKitPulls.insert(id)
        Task {
            do {
                try await ConversationManager.refreshMessagesFromCloud(for: id)
            } catch {
                print("Failed to pull messages from CloudKit: \(error)")
            }
            await _ = MainActor.run {
                activeCloudKitPulls.remove(id)
            }
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
        useSearch: Bool = false
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
            lastModified: Date.now,
            conversationID: conversationID
        )
        chat.messages.append(userMsg)
        conversation.lastInteracted = Date.now
        conversation.lastModified = Date.now
        conversation.agentUsed = agent
        conversation.modelUsed = modelName

        // Save user message immediately (only mark this new message for push)
        saveMessages(for: conversationID, changedMessageIDs: [userMsg.id])
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
                let service = Mistral(apiKey: apiKey)
                let stream = try await service.streamMessage(messages: chat.messages, modelName: modelName, agent: agent, useSearch: useSearch)

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
                        case .content(let text):
                            // Update message text
                            updatedMessage.text += text
                            updatedMessage.lastModified = Date.now

                            // Haptic feedback with decreasing intensity
                            #if os(iOS)
                            if withHapticFeedback && chunkCount < maxHapticChunks {
                                let intensity = 0.75 - (Double(chunkCount) / Double(maxHapticChunks))
                                self.triggerHapticFeedback(intensity: intensity)
                                chunkCount += 1
                            }
                            #endif

                        case .annotations(let annotations):
                            // Store annotations (typically arrive at end of stream)
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

                    // Only mark the assistant message for push (it's the only one that changed)
                    saveMessages(for: conversationID, changedMessageIDs: [assistantMessageID])
                    syncConversation(id: conversationID)
                    onCompletion?()

                    // Clean up if chat is no longer needed
                    cleanupUnusedChats()
                }
                
                if isChatNew { try? conversation.title = await service.generateChatName(messages: chat.messages) }
                // save again to make sure it saves our chat title
                try? ConversationManager.saveIndex(conversations: conversations, changedConversationID: conversationID)
                
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

        // Save system message immediately (only mark this new message for push)
        if conversation.hasMessages {
            saveMessages(for: conversationID, changedMessageIDs: [userMsg.id])
        }
    }

    // MARK: - Persistence

    func saveMessages(for id: UUID, changedMessageIDs: Set<UUID>? = nil) {
        guard let chat = loadedChats[id] else { return }

        do {
            try ConversationManager.saveMessages(for: id, messages: chat.messages, changedMessageIDs: changedMessageIDs)
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

    // MARK: - CloudKit Sync Support

    /// Remove deleted conversations from ChatCache
    /// Called when CloudKit sync detects conversations were deleted on another device
    /// - Parameter deletedIDs: Set of conversation IDs that were deleted
    @MainActor
    func removeDeletedConversations(_ deletedIDs: Set<UUID>) {
        print("  🔄 Removing \(deletedIDs.count) deleted conversation(s) from ChatCache")

        // Remove from conversations array
        conversations.removeAll { deletedIDs.contains($0.id) }

        // Remove from loaded chats
        for id in deletedIDs {
            loadedChats.removeValue(forKey: id)
        }

        // Clear selection if deleted
        if let activeID = activeConversationID, deletedIDs.contains(activeID) {
            activeConversationID = nil
        }
    }

    /// Update loaded conversations with newer versions from CloudKit
    /// Called after refresh to swap out loaded chats with updated data
    /// - Parameter updatedConversations: Array of conversations with latest data from CloudKit
    @MainActor
    func updateLoadedConversations(_ updatedConversations: [Conversation]) {
        print("  🔄 Updating loaded conversations in ChatCache")

        var updatedCount = 0

        // Update conversations array with newest versions
        for (index, conversation) in conversations.enumerated() {
            if let updated = updatedConversations.first(where: { $0.id == conversation.id }),
               updated.lastModified > conversation.lastModified {
                conversations[index] = updated
                updatedCount += 1
            }
        }

        // Add any new conversations from cloud that we don't have locally
        let localIDs = Set(conversations.map { $0.id })
        let newConversations = updatedConversations.filter { !localIDs.contains($0.id) }
        conversations.append(contentsOf: newConversations)

        if updatedCount > 0 || !newConversations.isEmpty {
            print("  ✅ Updated \(updatedCount) conversation(s), added \(newConversations.count) new")
        }

        // Note: LoadedChat doesn't store conversation metadata separately
        // The conversations array has already been updated above, which is what the UI uses
        // Messages in loadedChats are updated separately when conversations are opened

        print("  ✅ ChatCache updated with latest conversation metadata")
    }
}
