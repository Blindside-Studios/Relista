//
//  WebSearchTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct WebSearchTool: ChatTool {
    var name: String { "web_search" }
    var displayName: String { "Web Search" }
    var description: String { "Search the web for current information" }
    var icon: String { "globe" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "web_search",
                "description": "Search the web for current information. You will receive a response in natural language from a Mistral web search agent. The user can also see this response plus sources by expanding the tool use info panel.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query"
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        arguments["query"] as? String ?? "Searching…"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw NSError(domain: "WebSearchTool", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing required argument: query"
            ])
        }
        let agents = MistralAgents(apiKey: KeychainHelper.shared.mistralAPIKey)
        return try await agents.executeSearch(query: query)
    }
}
