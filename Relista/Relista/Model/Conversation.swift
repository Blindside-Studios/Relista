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
    var id: Int
    var title: String
    var uuid: UUID
    var lastInteracted: Date
    var modelUsed: String
    var isArchived: Bool

    // Note: messages are now managed separately in ChatCache

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case uuid
        case lastInteracted
        case modelUsed
        case isArchived
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        lastInteracted = try container.decode(Date.self, forKey: .lastInteracted)
        modelUsed = try container.decode(String.self, forKey: .modelUsed)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(lastInteracted, forKey: .lastInteracted)
        try container.encode(modelUsed, forKey: .modelUsed)
        try container.encode(isArchived, forKey: .isArchived)
    }

    // regular initializer for creating new conversations
    init(id: Int, title: String, uuid: UUID = UUID(), lastInteracted: Date = Date(), modelUsed: String, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.uuid = uuid
        self.lastInteracted = lastInteracted
        self.modelUsed = modelUsed
        self.isArchived = isArchived
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.uuid == rhs.uuid &&
               lhs.lastInteracted == rhs.lastInteracted &&
               lhs.modelUsed == rhs.modelUsed &&
               lhs.isArchived == rhs.isArchived
    }
}
