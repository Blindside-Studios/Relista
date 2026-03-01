//
//  AnalyzeImageTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import Foundation

/// A context-sensitive tool that lets the main model ask Pixtral targeted questions
/// about images attached to the current conversation. Q&A results are persisted in the
/// attachment index so they are injected into future turns without re-calling Pixtral.
struct AnalyzeImageTool: ChatTool {
    let conversationID: UUID

    var name: String { "analyze_image" }
    var displayName: String { "Analyze Image" }
    var description: String { "Ask Pixtral a question about an attached image" }
    var icon: String { "photo.badge.magnifyingglass" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "analyze_image",
                "description": """
                Ask Pixtral to analyze an image attached to the current message and answer a specific question about it.
                Pixtral is Mistral AI's multimodal model that will reply to your question with a natural language answer.
                Only call this for images listed in the current message's attachments section.
                Use the exact filename shown (e.g. "abc123.jpg").
                To get started, send the image to Pixtral, asking it to describe the image so you have a rough idea what it's about.
                Prefer targeted, specific questions rather than generic "describe this image" prompts for follow-up prompts.
                Your questions and Pixtral's responses are visible to the user and will be cached for you to read in subsequent chat turns.
                If a question has already been answered (visible in context above), do not ask it again.
                Make sure to properly judge if you need to run a new image analysis: prefer submitting new requests to Pixtral over guessing.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "filename": [
                            "type": "string",
                            "description": "The exact filename of the image to analyze (e.g. 'abc123.jpg')"
                        ],
                        "question": [
                            "type": "string",
                            "description": "A specific question to ask about the image"
                        ]
                    ],
                    "required": ["filename", "question"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        arguments["question"] as? String ?? "Analyzing image…"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let filename = arguments["filename"] as? String,
              let question = arguments["question"] as? String else {
            throw NSError(domain: "AnalyzeImageTool", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing required arguments: filename and question"
            ])
        }

        guard let imageData = AttachmentManager.loadImage(filename: filename, for: conversationID) else {
            return "Error: Could not load image '\(filename)'. Make sure to use the exact filename from the attachments section."
        }

        let ext = (filename as NSString).pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "png":         mimeType = "image/png"
        case "gif":         mimeType = "image/gif"
        case "webp":        mimeType = "image/webp"
        default:            mimeType = "image/jpeg"
        }

        let dataURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
        let apiKey = await MainActor.run { KeychainHelper.shared.mistralAPIKey }
        let answer = try await callPixtral(apiKey: apiKey, imageDataURL: dataURL, question: question)

        // Persist the Q&A so future turns see it without re-calling Pixtral
        let imageUUID = (filename as NSString).deletingPathExtension
        AttachmentManager.addQA(imageUUID: imageUUID, question: question, answer: answer, for: conversationID)

        return answer
    }

    private func callPixtral(apiKey: String, imageDataURL: String, question: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "pixtral-large-latest",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": imageDataURL]],
                        ["type": "text", "text": question]
                    ]
                ]
            ],
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AnalyzeImageTool", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected response from Pixtral"
            ])
        }

        return content
    }
}
