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
}
