//
//  Conversation.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.11.25.
//

import Foundation
import Observation

@Observable
class Conversation: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var lastInteracted: Date
    var modelUsed: String
    var agentUsed: UUID?
    var isArchived: Bool
    var hasMessages: Bool
    var lastModified: Date

    // Note: messages are now managed separately in ChatCache

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case lastInteracted
        case modelUsed
        case agentUsed
        case isArchived
        case hasMessages
        case lastModified
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)


        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        lastInteracted = try container.decode(Date.self, forKey: .lastInteracted)
        modelUsed = try container.decode(String.self, forKey: .modelUsed)
        agentUsed = try container.decode(UUID?.self, forKey: .agentUsed)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        hasMessages = try container.decodeIfPresent(Bool.self, forKey: .hasMessages) ?? true // Default to true for backward compatibility
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now // Backwards compatible
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(lastInteracted, forKey: .lastInteracted)
        try container.encode(modelUsed, forKey: .modelUsed)
        try container.encode(agentUsed, forKey: .agentUsed)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(hasMessages, forKey: .hasMessages)
        try container.encode(lastModified, forKey: .lastModified)
    }

    // regular initializer for creating new conversations
    init(id: UUID = UUID(), title: String, lastInteracted: Date = Date(), modelUsed: String, agentUsed: UUID?, isArchived: Bool = false, hasMessages: Bool = false, lastModified: Date = Date.now) {
        self.id = id
        self.title = title
        self.lastInteracted = lastInteracted
        self.modelUsed = modelUsed
        self.agentUsed = agentUsed
        self.isArchived = isArchived
        self.hasMessages = hasMessages
        self.lastModified = lastModified
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.lastInteracted == rhs.lastInteracted &&
               lhs.modelUsed == rhs.modelUsed &&
               lhs.agentUsed == rhs.agentUsed &&
               lhs.isArchived == rhs.isArchived &&
               lhs.hasMessages == rhs.hasMessages &&
               lhs.lastModified == rhs.lastModified
    }
}
