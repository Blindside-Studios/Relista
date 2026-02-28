//
//  Message.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation

struct Message: Identifiable, Codable{
    let id: UUID
    var text: String
    let role: MessageRole
    var modelUsed: String = "Unspecified Model"
    let attachmentLinks: [String]
    var timeStamp: Date
    var lastModified: Date
    var annotations: [MessageAnnotation]?
    var contentBlocks: [MessageContentBlock]?
    var conversationID: UUID

    // Custom Codable implementation for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, text, role, modelUsed, attachmentLinks, timeStamp, lastModified, annotations, contentBlocks, conversationID
    }

    init(id: UUID, text: String, role: MessageRole, modelUsed: String = "Unspecified Model", attachmentLinks: [String], timeStamp: Date, lastModified: Date = Date.now, annotations: [MessageAnnotation]? = nil, contentBlocks: [MessageContentBlock]? = nil, conversationID: UUID) {
        self.id = id
        self.text = text
        self.role = role
        self.modelUsed = modelUsed
        self.attachmentLinks = attachmentLinks
        self.timeStamp = timeStamp
        self.lastModified = lastModified
        self.annotations = annotations
        self.contentBlocks = contentBlocks
        self.conversationID = conversationID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        role = try container.decode(MessageRole.self, forKey: .role)
        modelUsed = try container.decodeIfPresent(String.self, forKey: .modelUsed) ?? "Unspecified Model"
        attachmentLinks = try container.decode([String].self, forKey: .attachmentLinks)
        timeStamp = try container.decode(Date.self, forKey: .timeStamp)
        // Backwards compatible: default to now if missing
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
        // Backwards compatible: annotations may not exist in old messages
        annotations = try container.decodeIfPresent([MessageAnnotation].self, forKey: .annotations)
        contentBlocks = try container.decodeIfPresent([MessageContentBlock].self, forKey: .contentBlocks)
        // Backwards compatible: conversationID may not exist in old messages
        // Will be set by ConversationManager.loadMessages() after loading
        conversationID = try container.decodeIfPresent(UUID.self, forKey: .conversationID) ?? UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(role, forKey: .role)
        try container.encode(modelUsed, forKey: .modelUsed)
        try container.encode(attachmentLinks, forKey: .attachmentLinks)
        try container.encode(timeStamp, forKey: .timeStamp)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(annotations, forKey: .annotations)
        try container.encodeIfPresent(contentBlocks, forKey: .contentBlocks)
        try container.encode(conversationID, forKey: .conversationID)
    }
}

enum MessageRole: String, Codable{
    case system, assistant, user
    
    func toAPIString() -> String {
            switch self {
            case .user: return "user"
            case .assistant: return "assistant"
            case .system: return "system"
            }
        }
}
