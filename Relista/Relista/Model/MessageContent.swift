//
//  MessageContent.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct ToolUseBlock: Codable, Equatable {
    let id: String
    let toolName: String
    let displayName: String
    let icon: String
    let inputSummary: String
    var result: String?
    var isLoading: Bool
}

struct ThinkingBlock: Codable, Equatable {
    var text: String
    var isLoading: Bool
}

enum MessageContentBlock: Codable, Equatable {
    case text(String)
    case toolUse(ToolUseBlock)
    case thinking(ThinkingBlock)

    private enum ContentType: String, Codable {
        case text
        case toolUse
        case thinking
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, toolUse, thinking
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ContentType.self, forKey: .type)
        switch type_ {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .toolUse:
            self = .toolUse(try container.decode(ToolUseBlock.self, forKey: .toolUse))
        case .thinking:
            self = .thinking(try container.decode(ThinkingBlock.self, forKey: .thinking))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .text)
        case .toolUse(let block):
            try container.encode(ContentType.toolUse, forKey: .type)
            try container.encode(block, forKey: .toolUse)
        case .thinking(let block):
            try container.encode(ContentType.thinking, forKey: .type)
            try container.encode(block, forKey: .thinking)
        }
    }
}
