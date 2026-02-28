//
//  FetchUserName.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct UserNameTool: ChatTool {
    var name: String { "fetch_user_name" }
    var displayName: String { "User Name" }
    var description: String { "Lets the model read your name" }
    var icon: String { "person.text.rectangle" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        "Fetching your name"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        
        return SyncedSettings.shared.userName
    }
}
