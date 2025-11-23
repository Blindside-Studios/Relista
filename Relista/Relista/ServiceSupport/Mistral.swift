//
//  Mistral.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation

/*struct MistralService {
    let apiKey: String
    
    func generateChatName(messages: [Message]) async throws -> String {
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemMessage: [String: String] = [
            "role": "user",
            "content": """
                    Create a short title (max 3 words) describing the topic of the FIRST user message and the FIRST assistant reply. 
                    Write the title only, nothing else. 
                    Do not mention "user", "assistant" or other roles. 
                    Describe the subject of the conversation, not the act of talking. 
                    Use the same language that the user used.
                    """
        ]
        
        let apiMessages = messages.map { message in
            [
                "role": message.role.toAPIString(),
                "content": message.text
            ]
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
        let firstChoice = choices[0]
        let messageObj = firstChoice["message"] as! [String: Any]
        return messageObj["content"] as! String
    }
    
    func streamMessage(messages: [Message], modelName: String) async throws -> AsyncThrowingStream<String, Error> {
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
        var prePrompt = ""
        if ChatCache.shared.selectedAgent != nil {
            let agent = AgentManager.getAgent(fromUUID: ChatCache.shared.selectedAgent!)
            if agent != nil {prePrompt = agent!.systemPrompt }
        }
        
        let systemMessage: [String: String] = [
            "role": "system",
            "content": prePrompt
        ]
        
        let apiMessages = [systemMessage] + messages.map { message in
            [
                "role": message.role.toAPIString(),
                "content": message.text
            ]
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
}*/
