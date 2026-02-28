//
//  RandomFruitTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct RandomFruitTool: ChatTool {
    var name: String { "random_fruit" }
    var displayName: String { "Random Fruit" }
    var description: String { "Pick a random fruit from a predefined list" }
    var icon: String { "leaf" }
    var defaultEnabled: Bool { false }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "random_fruit",
                "description": "Returns a random fruit from a predefined list. Call this when the user asks you to pick or suggest a random fruit.",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        "picking a random fruit"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        let fruits = [
            "apple", "banana", "mango", "strawberry", "kiwi",
            "pineapple", "watermelon", "grape", "peach", "pear",
            "cherry", "blueberry", "lemon", "papaya", "fig"
        ]
        return fruits.randomElement()!
    }
}
