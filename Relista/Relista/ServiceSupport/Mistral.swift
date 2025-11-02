//
//  Mistral.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation

struct MistralService {
    let apiKey: String
    
    func sendMessage(_ message: String) async throws -> String {
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "ministral-3b-latest",
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let firstChoice = choices[0]
        let messageObj = firstChoice["message"] as! [String: Any]
        return messageObj["content"] as! String
    }
    
    func streamMessage(messages: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("DEBUG: Converting \(messages.count) messages")
        
        // Convert Message array to API format
        let apiMessages = messages.map { message in
            [
                "role": message.role.toAPIString(),
                "content": message.text
            ]
        }
        
        print("DEBUG: API messages: \(apiMessages)")
        
        let body: [String: Any] = [
            "model": "mistral-small-latest",
            "messages": apiMessages,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        print("DEBUG: Got response: \(response)")
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
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
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
