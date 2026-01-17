//
//  ConversationManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.11.25.
//

import Foundation
import CloudKit

class ConversationManager {
    // MARK: - CloudKit Sync Engines

    /// Sync engine for conversation metadata
    private static let conversationSyncEngine: SyncEngine<Conversation> = {
        let container = CKContainer(identifier: "iCloud.Blindside-Studios.Relista")
        return SyncEngine(database: container.privateCloudDatabase)
    }()

    /// Sync engine for messages
    private static let messageSyncEngine: SyncEngine<Message> = {
        let container = CKContainer(identifier: "iCloud.Blindside-Studios.Relista")
        return SyncEngine(database: container.privateCloudDatabase)
    }()

    // MARK: - File System URLs

    // app document directory
    private static let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private static var relistaURL: URL {
        documentsURL.appendingPathComponent("Relista")
    }
    
    private static var conversationsURL: URL {
        relistaURL.appendingPathComponent("conversations")
    }
    
    private static var indexURL: URL {
        relistaURL.appendingPathComponent("index.json")
    }
    
    // create folder structure if it doesn't yet exist
    static func initializeStorage() throws {
        let fileManager = FileManager.default
        
        // create Relista folder
        if !fileManager.fileExists(atPath: relistaURL.path) {
            try fileManager.createDirectory(at: relistaURL, withIntermediateDirectories: true)
        }
        
        // create conversations folder
        if !fileManager.fileExists(atPath: conversationsURL.path) {
            try fileManager.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        }
    }
    
    // save index.json (without messages)
    // Only saves conversations that have messages - filters out empty conversations
    static func saveIndex(conversations: [Conversation], changedConversationID: UUID? = nil, syncToCloudKit: Bool = true) throws {
        // Filter to only include conversations with messages
        let conversationsToSave = conversations.filter { $0.hasMessages }

        // Clean up LOCAL folders for conversations that don't have messages
        // (but DON'T delete from CloudKit - that's handled separately)
        let conversationsToRemove = conversations.filter { !$0.hasMessages }
        for conversation in conversationsToRemove {
            let conversationFolder = conversationsURL.appendingPathComponent(conversation.id.uuidString)
            if FileManager.default.fileExists(atPath: conversationFolder.path) {
                try? FileManager.default.removeItem(at: conversationFolder)
            }
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted  // Makes it readable

        let data = try encoder.encode(conversationsToSave)
        try data.write(to: indexURL)

        // Sync conversations to CloudKit (unless called from sync itself)
        if syncToCloudKit {
            Task {
                // Only mark the specific conversation that changed (if provided)
                if let changedID = changedConversationID {
                    print("  📝 Marking conversation \(changedID.uuidString.prefix(8))... for push")
                    await conversationSyncEngine.markForPush(changedID)

                    await conversationSyncEngine.startDebouncedPush {
                        // Return current conversations for push
                        (try? ConversationManager.loadIndex()) ?? []
                    }
                } else {
                    // WARNING: Bulk push of all conversations - only do this if explicitly intended!
                    // Normal save operations should always provide a specific changedConversationID
                    print("  ⚠️  saveIndex() called with syncToCloudKit=true but no changedConversationID!")
                    print("  ⚠️  This will mark \(conversationsToSave.count) conversation(s) for push")
                    print("  ⚠️  Consider providing a specific changedConversationID to avoid unnecessary syncs")
                    // Don't actually mark them - this is likely a bug in the caller
                    // If bulk sync is truly needed, it should be done explicitly
                }
            }
        }
    }
    
    // load index.json
    static func loadIndex() throws -> [Conversation] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []  // No index yet, return empty
        }
        
        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([Conversation].self, from: data)
    }
    
    // save messages for a specific conversation
    // Only marks specific changed messages for push (avoids rate limiting)
    static func saveMessages(for conversationID: UUID, messages: [Message], changedMessageIDs: Set<UUID>? = nil, syncToCloudKit: Bool = true) throws {
        // create conversation folder if needed
        let conversationFolder = conversationsURL.appendingPathComponent(conversationID.uuidString)

        if !FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.createDirectory(at: conversationFolder, withIntermediateDirectories: true)
        }

        // save messages.json
        let messagesURL = conversationFolder.appendingPathComponent("messages.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(messages)
        try data.write(to: messagesURL)

        // Sync messages to CloudKit (unless called from CloudKit sync itself)
        if syncToCloudKit {
            Task {
                // Only mark changed messages for push (or all if not specified)
                let messagesToMark = changedMessageIDs ?? Set(messages.map { $0.id })
                print("  📝 Marking \(messagesToMark.count) message(s) for push")

                for messageID in messagesToMark {
                    await messageSyncEngine.markForPush(messageID)
                }

                await messageSyncEngine.startDebouncedPush {
                    // Return all messages from this conversation for push
                    (try? ConversationManager.loadMessages(for: conversationID)) ?? []
                }
            }
        }
    }

    // load messages for a specific conversation
    static func loadMessages(for conversationID: UUID) throws -> [Message] {
        let messagesURL = conversationsURL
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("messages.json")

        guard FileManager.default.fileExists(atPath: messagesURL.path) else {
            return []  // no messages yet
        }

        let data = try Data(contentsOf: messagesURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var messages = try decoder.decode([Message].self, from: data)

        // Backwards compatibility: Set conversationID for old messages that don't have it
        var needsResave = false
        for i in 0..<messages.count {
            // Check if this is an old message with placeholder UUID (from backwards-compatible decoder)
            // We can't directly check if it was missing, but we can infer from the value
            // Actually, the decoder sets it to UUID() if missing, so we should just always set it
            // to the correct conversationID for messages loaded from this conversation's folder
            if messages[i].conversationID.uuidString == "00000000-0000-0000-0000-000000000000"
                || messages[i].conversationID != conversationID {
                messages[i].conversationID = conversationID
                needsResave = true
            }
        }

        // Resave with conversationID if we updated any messages
        if needsResave {
            try saveMessages(for: conversationID, messages: messages, syncToCloudKit: false)
        }

        return messages
    }

    // delete a conversation and all its messages (LOCAL ONLY - no CloudKit sync)
    static func deleteConversationLocalOnly(id: UUID) throws {
        let conversationFolder = conversationsURL.appendingPathComponent(id.uuidString)

        // Remove the entire conversation folder if it exists
        if FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.removeItem(at: conversationFolder)
        }
    }

    // delete a conversation locally AND sync deletion to CloudKit
    static func deleteConversation(id: UUID) throws {
        // Delete local files first
        try deleteConversationLocalOnly(id: id)

        // Mark for CloudKit deletion and push immediately
        Task {
            await conversationSyncEngine.markForDelete(id)

            // Trigger push immediately (deletions are important, don't wait for debounce)
            await conversationSyncEngine.startDebouncedPush {
                (try? ConversationManager.loadIndex()) ?? []
            }
        }
    }
    
    static func createNewConversation(fromID: UUID?, usingAgent: Bool = false, withAgent: UUID? = nil) -> (newChatUUID: UUID, newAgent: UUID?) {
        // Unmark previous conversation as being viewed
        var agent: UUID? = nil
        if usingAgent { agent = withAgent }
        if let previousID = fromID {
            ChatCache.shared.setViewing(id: previousID, isViewing: false)
        }

        // Create new conversation
        let newConversation = ChatCache.shared.createConversation(agentUsed: agent)
        let newConvID = newConversation.id

        // Mark new conversation as being viewed
        ChatCache.shared.setViewing(id: newConvID, isViewing: true)

        return (newChatUUID: newConvID, newAgent: agent)
    }

    // MARK: - CloudKit Sync (Pull)

    /// Refresh conversations from CloudKit
    /// Pulls updated conversations and merges with local data
    /// Also updates ChatCache with newest versions of loaded chats
    static func refreshConversationsFromCloud() async throws {
        print("🔄 Refreshing conversations from CloudKit...")

        // Step 1: Pull deletion tombstones
        print("  🪦 Checking for deletion tombstones...")
        let deletedIDs = try await conversationSyncEngine.pullDeletions()
        print("  🪦 Found \(deletedIDs.count) deletion tombstone(s)")

        // Step 2: Remove deleted conversations locally
        if !deletedIDs.isEmpty {
            print("  🗑️  Processing deletions for: \(deletedIDs.map { $0.uuidString.prefix(8) })")
            var currentConversations = (try? loadIndex()) ?? []
            let beforeCount = currentConversations.count
            currentConversations.removeAll { deletedIDs.contains($0.id) }
            let afterCount = currentConversations.count
            print("  🗑️  Removed \(beforeCount - afterCount) conversation(s) from local index (was \(beforeCount), now \(afterCount))")

            // Save updated index
            try saveIndex(conversations: currentConversations, syncToCloudKit: false)

            // Delete conversation folders (local only - already deleted in CloudKit)
            for id in deletedIDs {
                try? deleteConversationLocalOnly(id: id)
            }

            // Update ChatCache to remove deleted conversations
            await ChatCache.shared.removeDeletedConversations(Set(deletedIDs))
            print("  ✅ Removed \(deletedIDs.count) deleted conversation(s) from ChatCache")
        } else {
            print("  ✅ No deletions to process")
        }

        // Step 3: Pull updated conversations from CloudKit
        let cloudConversations = try await conversationSyncEngine.pull()

        // Step 4: Merge with local conversations (newest wins)
        var localConversations = (try? loadIndex()) ?? []
        let merged = SyncMerge.merge(
            cloudItems: cloudConversations,
            into: localConversations,
            itemName: "conversation"
        )

        // Step 5: Save merged conversations
        try saveIndex(conversations: merged, syncToCloudKit: false)

        // Step 6: Update ChatCache with newest versions of loaded chats
        await ChatCache.shared.updateLoadedConversations(merged)

        print("✅ Conversations refreshed: now have \(merged.count) total")
    }

    /// Refresh messages for a specific conversation from CloudKit
    /// Called when loading a conversation to ensure we have the latest messages
    /// - Parameter conversationID: The ID of the conversation to refresh
    static func refreshMessagesFromCloud(for conversationID: UUID) async throws {
        print("🔄 Refreshing messages for conversation \(conversationID.uuidString.prefix(8))...")

        // Pull all messages from CloudKit (SyncEngine uses incremental sync with lastSyncDate)
        let allCloudMessages = try await messageSyncEngine.pull()

        // Filter to only messages for this conversation
        print("  🔍 Filtering \(allCloudMessages.count) message(s) for conversation \(conversationID.uuidString.prefix(8))...")
        let cloudMessages = allCloudMessages.filter { $0.conversationID == conversationID }

        // Debug: Show what conversationIDs we got from CloudKit
        if allCloudMessages.count > 0 && cloudMessages.isEmpty {
            let uniqueConvIDs = Set(allCloudMessages.map { $0.conversationID.uuidString.prefix(8) })
            print("  ⚠️  Found messages but none match! CloudKit has messages for: \(uniqueConvIDs)")
        }

        if cloudMessages.isEmpty {
            print("  📭 No messages from CloudKit for this conversation")
            return
        }

        print("  📥 Pulled \(cloudMessages.count) message(s) from CloudKit")

        // Load local messages
        var localMessages = (try? loadMessages(for: conversationID)) ?? []

        // Merge messages (newest wins based on lastModified)
        let merged = SyncMerge.merge(
            cloudItems: cloudMessages,
            into: localMessages,
            itemName: "message"
        )

        // Save merged messages (without triggering CloudKit sync to avoid loop)
        try saveMessages(for: conversationID, messages: merged, syncToCloudKit: false)

        // Update ChatCache if this conversation is loaded
        if let loadedChat = await ChatCache.shared.loadedChats[conversationID] {
            await MainActor.run {
                loadedChat.messages = merged
            }
            print("  ✅ Updated loaded chat with \(merged.count) message(s)")
        } else {
            print("  ✅ Saved \(merged.count) message(s) to disk")
        }
    }
}
