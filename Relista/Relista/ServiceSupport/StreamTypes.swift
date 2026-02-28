//
//  StreamTypes.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

enum StreamChunk {
    case content(String)
    case annotations([MessageAnnotation])
    case toolUseStarted(id: String, toolName: String, displayName: String, icon: String, inputSummary: String)
    case toolResultReceived(id: String, result: String)
    case thinkingChunk(String)
}
