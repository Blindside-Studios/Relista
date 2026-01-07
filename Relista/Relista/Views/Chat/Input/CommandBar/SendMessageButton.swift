//
//  SendMessageButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct SendMessageButton: View {
    @Binding var conversationID: UUID
    @State var chatCache = ChatCache.shared
    
    let sendMessage: () -> Void
    let sendMessageAsSystem: () -> Void
    
    @Binding var accentColor: Color
    
    var body: some View {
        Button {
            let chat = chatCache.getChat(for: conversationID)
            if chat.isGenerating {
                chatCache.cancelGeneration(for: conversationID)
            } else {
                sendMessage()
            }
        } label: {
            // Access chat directly from cache to avoid infinite loop
            let chat = chatCache.loadedChats[conversationID]
            let isGenerating = chat?.isGenerating ?? false

            ZStack{
                Label("Stop generating", systemImage: "stop.fill")
                    .offset(y: isGenerating ? 0 : 25)
                Label("Send message", systemImage: "arrow.up")
                    .offset(y: isGenerating ? -25 : 0)
            }
            .font(.headline)
            // weirdly these seem to be interpreted differently across platforms
            #if os(macOS)
            .frame(width: 18, height: 18)
            #else
            .frame(width: 19, height: 19)
            #endif
            .animation(.bouncy(duration: 0.3, extraBounce: 0.15), value: isGenerating)
        }
        .buttonStyle(.glassProminent)
        .tint(accentColor)
        .animation(.default, value: accentColor)
        .labelStyle(.iconOnly)
        .buttonBorderShape(.circle)
        .clipped()
        // weirdly these seem to be interpreted differently across platforms
        #if os(macOS)
        .offset(x: 0, y: 2)
        #else
        .offset(x: 8, y: 1)
        #endif
        .padding(.horizontal, -7)
        .contextMenu {
            Button {
                sendMessageAsSystem()
            } label: {
                Label("Send as system message", systemImage: "exclamationmark.bubble")
            }
        }
    }
}

#Preview {
    //SendMessageButton()
}
