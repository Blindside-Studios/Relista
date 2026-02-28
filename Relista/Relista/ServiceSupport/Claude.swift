//
//  Claude.swift
//  Relista
//
//  Created by Nicolas Helbig on 25.01.26.
//

import Foundation
import SwiftUI

struct Claude {
    let apiKey: String

    var url: URL {
        URL(string: "https://api.anthropic.com/v1/messages")!
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func streamMessage(messages: [Message], modelName: String, agent: UUID?, tools: [any ChatTool] = []) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        var request = makeRequest()
        let defaultInstructions = await MainActor.run { SyncedSettings.shared.defaultInstructions }

        let systemPrompt = agent == nil ? defaultInstructions : agent
            .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""

        // Claude uses a different message format - system is separate, not in messages array
        let apiMessages: [[String: Any]] = messages.map { message in
            var content = message.text
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = "[No message content]"
            }
            return ["role": message.role.toAPIString(), "content": content]
        }

        // Tools not yet implemented for Claude
        _ = tools

        print("Model being used: \(modelName)")

        var body: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "max_tokens": 8192,
            "stream": true
        ]

        // Add system prompt if not empty
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Skip empty lines and event type lines
                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)

                        // Check for stream end
                        if data == "[DONE]" {
                            continuation.finish()
                            return
                        }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                            continue
                        }

                        // Check for error
                        if let errorDict = json["error"] as? [String: Any] {
                            let errorMessage = errorDict["message"] as? String ?? "Unknown error"
                            let error = NSError(domain: "Claude", code: 1, userInfo: [
                                NSLocalizedDescriptionKey: errorMessage
                            ])
                            continuation.finish(throwing: error)
                            return
                        }

                        // Handle different event types
                        let eventType = json["type"] as? String

                        switch eventType {
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(.content(text))
                            }

                        case "message_stop":
                            continuation.finish()
                            return

                        case "error":
                            if let errorDict = json["error"] as? [String: Any] {
                                let errorMessage = errorDict["message"] as? String ?? "Unknown error"
                                let error = NSError(domain: "Claude", code: 1, userInfo: [
                                    NSLocalizedDescriptionKey: errorMessage
                                ])
                                continuation.finish(throwing: error)
                                return
                            }

                        default:
                            // Ignore other event types (message_start, content_block_start, etc.)
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
