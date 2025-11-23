//
//  OpenRouter.swift
//  Relista
//
//  Created by Nicolas Helbig on 22.11.25.
//

import Foundation

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
            Create a short title (max 3 words) describing the topic of the FIRST user message and the FIRST assistant reply.
            Only the title.
            Same language as the user.
            """
        ]
        
        let apiMessages = messages.map {
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
    
    func streamMessage(messages: [Message], modelName: String) async throws -> AsyncThrowingStream<String, Error> {
        var request = makeRequest()
        
        let systemMessage = [
            "role": "system",
            "content": ChatCache.shared.selectedAgent
                .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        ]
        
        let apiMessages = [systemMessage] + messages.map {
            ["role": $0.role.toAPIString(), "content": $0.text]
        }

        let body: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)
                        if data == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
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
