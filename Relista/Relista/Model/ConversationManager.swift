//
//  ConversationManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.11.25.
//

import Foundation

import Foundation

class ConversationManager {
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
            // Only mark the specific conversation that changed (if provided)
            if let changedID = changedConversationID {
                CloudKitSyncManager.shared.markConversationChanged(changedID)
            }
            CloudKitSyncManager.shared.debouncedPush()
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
    static func saveMessages(for conversationID: UUID, messages: [Message], syncToCloudKit: Bool = true) throws {
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
            CloudKitSyncManager.shared.markMessagesChanged(for: conversationID)
            CloudKitSyncManager.shared.debouncedPush()
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

        return try decoder.decode([Message].self, from: data)
    }

    // delete a conversation and all its messages
    static func deleteConversation(id: UUID) throws {
        let conversationFolder = conversationsURL.appendingPathComponent(id.uuidString)

        // Remove the entire conversation folder if it exists
        if FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.removeItem(at: conversationFolder)
        }

        // Delete from CloudKit
        Task {
            do {
                try await CloudKitSyncManager.shared.deleteConversation(id)
            } catch {
                print("Error deleting conversation from CloudKit: \(error)")
            }
        }
    }
    
    static func createNewConversation(fromID: UUID?, usingAgent: Bool = false, withAgent: UUID? = nil) -> UUID {
        // Unmark previous conversation as being viewed
        if let previousID = fromID {
            ChatCache.shared.setViewing(id: previousID, isViewing: false)
        }

        // Create new conversation
        let newConversation = ChatCache.shared.createConversation(agentUsed: withAgent)
        let newConvID = newConversation.id

        // Mark new conversation as being viewed
        ChatCache.shared.setViewing(id: newConvID, isViewing: true)
        
        return newConvID
    }
}
