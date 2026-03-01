//
//  Mistral.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation
import SwiftUI

struct Mistral {
    let apiKey: String

    var url: URL {
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
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let messageObj = choices.first?["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw NSError(domain: "Mistral", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from chat name API"])
        }
        return content
    }

    func generateGreetingBanner(agent: UUID?) async throws -> String {
        var request = makeRequest()
        let defaultInstructions = await MainActor.run { SyncedSettings.shared.defaultInstructions }
        let userName = await MainActor.run { SyncedSettings.shared.userName }
                
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' HH:mm"
        var timeString = formatter.string(from: Date.now)
        if Int.random(in: 1...2) != 1 { timeString = "unspecified" }
        
        let instructions = agent == nil ? defaultInstructions : agent
            .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        
        let systemMessage = [
            "role": "user",
            "content": """
            You will write a short greeting (keep it brief, up to 3 to 8 words) to be displayed in the UI of a chat application as a banner above the text input box.
            This greeting will not be part of the conversation later-on, it is just meant to invite the user to type something.
            Further below, you will find the system prompt for your current persona that the user has specified.
            Stylistically, you will adopt said persona and make sure its personality shines through clearly while focusing on what makes sense as a greeting.
            Disregard formatting requests as well as those for stage directions.
            Keep the greeting engaging, slightly endearing and interesting without overdoing it.
            
            Here are the criteria your greetings must follow with positive and negative examples:
            If the user-specified instructions request the use of another language, use that language. For example, if instructed to speak German:
            Good response: Hey, wie läuft's?
            Bad response: Hey, what's up?
            
            If the system adds helpful parameters, do not go for generic greetings. For example, if the time is stated to be 22:30:
            Good response: Still working, night owl?
            Bad response: Good evening
            
            Do not wrap your answer in quotation marks:
            Good response: I got you!
            Bas response: "I got you!"
            
            Do not end your sentence with periods. Exclamation and question marks are allowed:
            Good response: Happy to see you
            Bad response: Happy to see you.
            
            CRITICAL: Do NOT markdown format responses or use stage directions:
            Good response: What's up now?
            Bad response: *smirks* What's up now?
            
            Here is helpful data to allow you to make your answers more personalized (if a field is blank, do not mention it).
            You may not use the name consistently as it would be creepy, only use it rarely and if you feel it adds to the greeting you wrote.
            Use the time OCCASIONALLY to customize your greeting to fit a late evening vibe or even comment on the current date, wishing to use Merry Christmas etc.
            User-specified name: \(userName)
            Current date and time: \(timeString)
            
            If the user-specified instructions are blank, you should fall back to general-purpose, friendly greetings, still with personality.
            Below is your persona's system prompt as given by the user.
            -- PERSONA SYSTEM PROMPT --
            \(instructions)
            -- END OF PERSONA SYSTEM PROMPT --
            
            KEEP IN MIND THAT YOUR RESPONSES MUST NOT BE LONGER THAN 8 WORDS AND YOU MUST DISREGARD INSTRUCTIONS FROM THE USER ABOUT MESSAGE LENGTH, STAGE DIRECTIONS OR MARKDOWN!!!
            I REPEAT: NO STAGE DIRECTIONS, NO FORMATTING, NO LINE BREAKS OR NEWLINES, NO QUOTATION MARKS, NO ASTERISKS!!!
            YOUR ENTIRE RESPONSE SHOULD BE THE GREETING FOR THE UI AND NOTHING ELSE!!!
            """
        ]

        let apiMessages = [systemMessage]

        let body: [String: Any] = [
            "model": "ministral-8b-latest",
            "messages": apiMessages,
            "stream": false,
            "temperature": 1.0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let messageObj = choices.first?["message"] as? [String: Any],
              let greeting = messageObj["content"] as? String else {
            throw NSError(domain: "Mistral", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from greeting banner API"])
        }
        
        // we will be sanitizing this content because depending on the user's instructions, the model may still try to markdown.
        var cleaned = greeting
                // remove everything inside and including asterisks (role play stage directions)
                .replacingOccurrences(of: #"\*[^*]*\*"#, with: "", options: .regularExpression)
                // remove remaining standalone asterisks
                .replacingOccurrences(of: "*", with: "")
                // remove all line breaks
                .replacingOccurrences(of: "\n", with: " ")
                // replace em dashes with spaced hyphens
                .replacingOccurrences(of: "—", with: " - ")
                // trim whitespace
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // remove leading/trailing quotes
            if cleaned.hasPrefix("\"") { cleaned.removeFirst() }
            if cleaned.hasSuffix("\"") { cleaned.removeLast() }
            
            // clean up multiple spaces
            cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            
            let finalGreeting = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
            return finalGreeting
    }

    func streamMessage(messages: [Message], modelName: String, agent: UUID?, tools: [any ChatTool] = []) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        var request = makeRequest()
        let (defaultInstructions, memorySuffix) = await MainActor.run {
            (SyncedSettings.shared.defaultInstructions, SyncedSettings.memoryContext(for: agent))
        }

        let baseContent = agent == nil ? defaultInstructions : agent
            .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        let systemMessage = ["role": "system", "content": baseContent + memorySuffix]

        let apiMessages = [systemMessage] + messages.map { message in
            var content = message.text
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = "[No message content]"
            }
            // Inject attachment context directly into the user message content so it
            // works within Mistral's constraint of no system messages after the first exchange.
            if !message.attachmentLinks.isEmpty,
               let attachmentContext = AttachmentManager.attachmentContextBlock(
                for: message.attachmentLinks, in: message.conversationID) {
                content += "\n\n" + attachmentContext
            }
            return ["role": message.role.toAPIString(), "content": content]
        }

        let supportsReasoning = ModelList.getModelFromSlug(slug: modelName).supportsReasoning

        var body: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "stream": true
        ]

        if supportsReasoning {
            body["prompt_mode"] = "reasoning"
        }

        if !tools.isEmpty {
            body["tools"] = tools.map { $0.definition }
            print("🔧 Tools enabled: \(tools.map { $0.name }.joined(separator: ", "))")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        return AsyncThrowingStream { continuation in
            let capturedRequest = request
            let capturedMessages = apiMessages
            let capturedModelName = modelName
            let capturedTools = tools
            let capturedSupportsReasoning = supportsReasoning

            Task {
                var accumulatedToolCalls: [String: [String: Any]] = [:]
                var assistantMessage = ""

                do {
                    for try await line in bytes.lines {
                        if !line.isEmpty {
                            print("📥 Received line: \(line)")
                        }

                        if line.hasPrefix("{") && line.contains("\"error\"") {
                            if let jsonData = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let errorDict = json["error"] as? [String: Any] {
                                let error = NSError(domain: "Mistral", code: 1, userInfo: [
                                    NSLocalizedDescriptionKey: errorDict["message"] as? String ?? "Unknown error",
                                    "type": errorDict["type"] as? String ?? "unknown",
                                    "code": errorDict["code"] as? String ?? "unknown"
                                ])
                                continuation.finish(throwing: error)
                                return
                            }
                        }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)
                        if data == "[DONE]" { continuation.finish(); return }

                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let choice = choices.first {

                            let delta = choice["delta"] as? [String: Any]
                            let finishReason = choice["finish_reason"] as? String

                            // Accumulate tool call deltas
                            if let delta = delta, let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                                for toolCall in toolCalls {
                                    if let index = toolCall["index"] as? Int {
                                        let id = toolCall["id"] as? String ?? "\(index)"
                                        if accumulatedToolCalls[id] == nil {
                                            accumulatedToolCalls[id] = [
                                                "id": id,
                                                "type": toolCall["type"] as? String ?? "function",
                                                "function": ["name": "", "arguments": ""]
                                            ]
                                        }
                                        if let function = toolCall["function"] as? [String: Any] {
                                            var fn = accumulatedToolCalls[id]?["function"] as? [String: String] ?? ["name": "", "arguments": ""]
                                            if let name = function["name"] as? String { fn["name"] = name }
                                            if let args = function["arguments"] as? String { fn["arguments"]? += args }
                                            accumulatedToolCalls[id]?["function"] = fn
                                        }
                                    }
                                }
                            }

                            // Yield content/thinking chunks
                            // Magistral returns delta.content as an array of typed blocks;
                            // standard models return it as a plain string.
                            if let delta = delta {
                                if let contentArray = delta["content"] as? [[String: Any]] {
                                    for block in contentArray {
                                        let blockType = block["type"] as? String
                                        if blockType == "thinking" {
                                            if let thinkingItems = block["thinking"] as? [[String: Any]] {
                                                for item in thinkingItems {
                                                    if let text = item["text"] as? String, !text.isEmpty {
                                                        continuation.yield(.thinkingChunk(text))
                                                    }
                                                }
                                            }
                                        } else if blockType == "text" {
                                            if let text = block["text"] as? String, !text.isEmpty {
                                                assistantMessage += text
                                                continuation.yield(.content(text))
                                            }
                                        }
                                    }
                                } else if let content = delta["content"] as? String, !content.isEmpty {
                                    assistantMessage += content
                                    continuation.yield(.content(content))
                                }
                            }

                            // Yield annotations
                            if let delta = delta, let annotationsData = delta["annotations"] as? [[String: Any]],
                               let annotations = try? self.parseAnnotations(annotationsData) {
                                continuation.yield(.annotations(annotations))
                            }

                            // Execute tool calls when stream signals completion
                            if finishReason == "tool_calls" && !accumulatedToolCalls.isEmpty {
                                print("🔧 Stream finished with \(accumulatedToolCalls.count) tool call(s), executing...")

                                for (_, toolCall) in accumulatedToolCalls {
                                    guard let function = toolCall["function"] as? [String: String],
                                          let functionName = function["name"],
                                          let argumentsString = function["arguments"],
                                          let tool = capturedTools.first(where: { $0.name == functionName }) else {
                                        print("⚠️ Unknown or malformed tool call: \(toolCall)")
                                        continue
                                    }

                                    let args = (try? JSONSerialization.jsonObject(
                                        with: Data(argumentsString.utf8)
                                    ) as? [String: Any]) ?? [:]
                                    let toolCallID = toolCall["id"] as? String ?? "0"

                                    print("🔧 Executing tool: \(functionName)")
                                    continuation.yield(.toolUseStarted(
                                        id: toolCallID,
                                        toolName: tool.name,
                                        displayName: tool.displayName,
                                        icon: tool.icon,
                                        inputSummary: tool.inputSummary(from: args)
                                    ))

                                    let result = try await tool.execute(arguments: args)
                                    continuation.yield(.toolResultReceived(id: toolCallID, result: result))

                                    // Build follow-up request with the tool result
                                    var newMessages: [[String: Any]] = capturedMessages.map { $0 as [String: Any] }
                                    var toolCallMessage: [String: Any] = ["role": "assistant", "tool_calls": [toolCall]]
                                    if !assistantMessage.isEmpty { toolCallMessage["content"] = assistantMessage }
                                    newMessages.append(toolCallMessage)
                                    newMessages.append([
                                        "role": "tool",
                                        "tool_call_id": toolCallID,
                                        "content": result
                                    ])

                                    var newRequest = capturedRequest
                                    var newBody: [String: Any] = [
                                        "model": capturedModelName,
                                        "messages": newMessages,
                                        "stream": true
                                    ]
                                    if capturedSupportsReasoning {
                                        newBody["prompt_mode"] = "reasoning"
                                    }
                                    newRequest.httpBody = try JSONSerialization.data(withJSONObject: newBody)

                                    print("🔄 Sending follow-up request...")
                                    let (newBytes, _) = try await URLSession.shared.bytes(for: newRequest)
                                    for try await newLine in newBytes.lines {
                                        guard newLine.hasPrefix("data: ") else { continue }
                                        let newData = newLine.dropFirst(6)
                                        if newData == "[DONE]" { continuation.finish(); return }
                                        if let newJsonData = newData.data(using: .utf8),
                                           let newJson = try? JSONSerialization.jsonObject(with: newJsonData) as? [String: Any],
                                           let newChoices = newJson["choices"] as? [[String: Any]],
                                           let newContent = newChoices.first?["delta"] as? [String: Any],
                                           let text = newContent["content"] as? String {
                                            continuation.yield(.content(text))
                                        }
                                    }
                                    continuation.finish()
                                    return
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
