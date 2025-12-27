//
//  Mistral.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation
import SwiftUI

enum StreamChunk {
    case content(String)
    case annotations([MessageAnnotation])
}

struct Mistral {
    let apiKey: String

    private var url: URL {
        URL(string: "https://api.mistral.ai/v1/chat/completions")!
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func generateChatName(messages: [Message]) async throws -> String {
        var request = makeRequest()

        let systemMessage = [
            "role": "user",
            "content": """
            Create a short title (3 words, max 4 words) describing the topic of the FIRST user message and the FIRST assistant reply.
            Output the title as plain text only - no quotes, no punctuation marks around it.
            Same language as the user.

            Incorrect: "Recipe Ideas"
            Correct: Recipe Ideas
            """
        ]

        let apiMessages = messages.filter{$0.role == .assistant || $0.role == .user}.map {
            ["role": $0.role.toAPIString(), "content": $0.text]
        } + [systemMessage]

        let body: [String: Any] = [
            "model": "ministral-3b-latest",
            "messages": apiMessages,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let messageObj = choices[0]["message"] as! [String: Any]
        return messageObj["content"] as! String
    }

    func streamMessage(messages: [Message], modelName: String, agent: UUID?, useSearch: Bool = false) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        var request = makeRequest()
        @AppStorage("DefaultAssistantInstructions") var defaultInstructions: String = ""

        let systemMessage = [
            "role": "system",
            "content": agent == nil ? defaultInstructions : agent
                .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        ]

        let apiMessages = [systemMessage] + messages.map { message in
            var content = message.text
            // replace blank messages with placeholder (Mistral requires non-empty content)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = "[No message content]"
            }
            return ["role": message.role.toAPIString(), "content": content]
        }

        // Note: Mistral API supports web searches but it's not yet implemented, like reasoning
        // The useSearch parameter is kept for API compatibility but ignored
        if useSearch {
            print("⚠️ Web search requested not yet implemented for Mistral")
        }

        print("🔍 Model being used: \(modelName)")
        print("📨 Request URL: \(request.url?.absoluteString ?? "nil")")
        print("📨 Request headers: \(request.allHTTPHeaderFields ?? [:])")

        let body: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Log every line received for debugging
                        if !line.isEmpty {
                            print("📥 Received line: \(line)")
                        }

                        // check for error responses (they don't have "data: " prefix)
                        if line.hasPrefix("{") && line.contains("\"error\"") {
                            print("❌ ERROR RESPONSE DETECTED")
                            print("❌ Full error line: \(line)")

                            if let jsonData = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                print("❌ Parsed error JSON: \(json)")

                                if let errorDict = json["error"] as? [String: Any] {
                                    print("❌ Error dict: \(errorDict)")
                                    let errorMessage = errorDict["message"] as? String ?? "Unknown error"
                                    let errorType = errorDict["type"] as? String ?? "unknown"
                                    let errorCode = errorDict["code"] as? String ?? "unknown"

                                    print("❌ Error message: \(errorMessage)")
                                    print("❌ Error type: \(errorType)")
                                    print("❌ Error code: \(errorCode)")

                                    let error = NSError(domain: "Mistral", code: 1, userInfo: [
                                        NSLocalizedDescriptionKey: errorMessage,
                                        "type": errorType,
                                        "code": errorCode
                                    ])
                                    continuation.finish(throwing: error)
                                    return
                                }
                            }
                        }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)
                        if data == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any] {

                            // yield content if present
                            if let content = delta["content"] as? String {
                                continuation.yield(.content(content))
                            }

                            // yield annotations if present (though Mistral may not support this)
                            if let annotationsData = delta["annotations"] as? [[String: Any]] {
                                let annotations = try? self.parseAnnotations(annotationsData)
                                if let annotations = annotations {
                                    continuation.yield(.annotations(annotations))
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseAnnotations(_ annotationsData: [[String: Any]]) throws -> [MessageAnnotation] {
        let jsonData = try JSONSerialization.data(withJSONObject: annotationsData)
        let decoder = JSONDecoder()
        return try decoder.decode([MessageAnnotation].self, from: jsonData)
    }
}
