//
//  ChatTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

/// A tool that can be offered to the model and invoked during a chat turn.
/// Add new tools by creating a struct in ServiceSupport/Tools/ that conforms to this protocol,
/// then registering it in ToolRegistry.allTools.
protocol ChatTool {
    /// Machine-readable name sent to the API (must match the function name in `definition`)
    var name: String { get }
    /// Human-readable name shown in the UI
    var displayName: String { get }
    /// One-line description shown in the tool picker
    var description: String { get }
    /// SF Symbol name used for the tool's icon
    var icon: String { get }
    /// Whether the tool is on by default before the user changes anything
    var defaultEnabled: Bool { get }
    /// The tool definition object sent to the model in the API request's `tools` array
    var definition: [String: Any] { get }
    /// A short human-readable summary of what the model is doing with this tool call,
    /// shown in the inline ToolUseView card during generation
    func inputSummary(from arguments: [String: Any]) -> String
    /// Execute the tool with the parsed arguments and return a result string for the model
    func execute(arguments: [String: Any]) async throws -> String
}
