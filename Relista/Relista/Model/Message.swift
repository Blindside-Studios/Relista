//
//  Message.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation

struct Message: Identifiable{
    let id: Int
    var text: String
    let role: MessageRole
}

enum MessageRole{
    case system, assistant, user
    
    func toAPIString() -> String {
            switch self {
            case .user: return "user"
            case .assistant: return "assistant"
            case .system: return "system"
            }
        }
}
