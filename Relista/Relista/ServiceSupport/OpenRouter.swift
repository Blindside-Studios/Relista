//
//  OpenRouter.swift
//  Relista
//
//  Created by Nicolas Helbig on 22.11.25.
//

/*
import Foundation
import SwiftUI

enum StreamChunk {
    case content(String)
    case annotations([MessageAnnotation])
}

struct OpenRouter {
    let apiKey: String
    let referer: String = "https://local.app"
    let appName: String = "Relista"
    
    private var url: URL {
        URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(appName, forHTTPHeaderField: "X-Title")
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
            "model": "mistralai/ministral-3b",
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
        
        let apiMessages = [systemMessage] + messages.map {
            ["role": $0.role.toAPIString(), "content": $0.text]
        }

        var model = modelName
        if useSearch { model = model + ":online" }

        print("🔍 Model being used: \(model)")
        print("🔍 Search enabled: \(useSearch)")

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Check for error responses (they don't have "data: " prefix)
                        if line.hasPrefix("{") && line.contains("\"error\"") {
                            if let jsonData = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let errorDict = json["error"] as? [String: Any],
                               let errorMessage = errorDict["message"] as? String {
                                let error = NSError(domain: "OpenRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                                continuation.finish(throwing: error)
                                return
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

                            // Yield content if present
                            if let content = delta["content"] as? String {
                                continuation.yield(.content(content))
                            }

                            // Yield annotations if present (typically at the end of stream)
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

    /// Parses annotations from JSON response data
    private func parseAnnotations(_ annotationsData: [[String: Any]]) throws -> [MessageAnnotation] {
        let jsonData = try JSONSerialization.data(withJSONObject: annotationsData)
        let decoder = JSONDecoder()
        return try decoder.decode([MessageAnnotation].self, from: jsonData)
    }
}
*/
