//
//  MessageModel.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import MarkdownUI

struct MessageModel: View {
    let messageText: String
    
    var body: some View {
        VStack{
            HStack {
                Markdown(messageText)
                    .textSelection(.enabled)
                    .padding()
                
                Spacer()
            }
            HStack(spacing: 8) {
                Button("Copy", systemImage: "doc.on.doc") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(messageText, forType: .string)
                    #else
                    UIPasteboard.general.string = messageText
                    #endif
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                
                Button("Regenerate", systemImage: "arrow.clockwise") {
                    // regrenerate
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                
                Spacer()
            }
            .padding(.leading, 15)
            .opacity(0.6)
            .padding(.top, -10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

#Preview {
    MessageModel(messageText: "User message")
}
