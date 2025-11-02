//
//  Message.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation

struct Message: Identifiable{
    var id: Int
    var text: String
    var role: MessageRole
}

enum MessageRole{
    case system, assistant, user
}
