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
    static func saveIndex(conversations: [Conversation]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted  // Makes it readable
        
        let data = try encoder.encode(conversations)
        try data.write(to: indexURL)
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
    static func saveMessages(for conversationUUID: UUID, messages: [Message]) throws {
        // create conversation folder if needed
        let conversationFolder = conversationsURL.appendingPathComponent(conversationUUID.uuidString)

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
    }
    
    // load messages for a specific conversation
    static func loadMessages(for conversationUUID: UUID) throws -> [Message] {
        let messagesURL = conversationsURL
            .appendingPathComponent(conversationUUID.uuidString)
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
    static func deleteConversation(uuid: UUID) throws {
        let conversationFolder = conversationsURL.appendingPathComponent(uuid.uuidString)

        // Remove the entire conversation folder if it exists
        if FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.removeItem(at: conversationFolder)
        }
    }
}
