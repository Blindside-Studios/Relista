//
//  CommandBar.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct CommandBar: View {
    @Binding var useSearch: Bool
    @Binding var useReasoning: Bool
    @Binding var selectedModel: String
    @State var chatCache = ChatCache.shared
    @Binding var conversationID: UUID
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let sendMessage: () -> Void
    let sendMessageAsSystem: () -> Void
    let appendDummyMessages: () -> Void
    
    var body: some View {
        #if os(macOS)
        let spacing: CGFloat = 12
        #else
        let spacing: CGFloat = 16
        #endif
        
        HStack {
            HStack(alignment: .center, spacing: spacing){
                Button("Simulate message flow", systemImage: "ant") {
                    appendDummyMessages()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                
                SearchButton(useSearch: $useSearch)
                
                ReasoningButton(useReasoning: $useReasoning)
                
                if horizontalSizeClass == .compact{
                    Spacer()
                }
                
                ModelPicker(selectedModel: $selectedModel)
                
                if horizontalSizeClass != .compact{
                    Spacer()
                }
            }
            .opacity(0.75)
            
            SendMessageButton(conversationID: $conversationID, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem)
        }
        .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useSearch)
        .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useReasoning)
        .frame(maxHeight: 16)
    }
}

#Preview {
    //CommandBar()
}
