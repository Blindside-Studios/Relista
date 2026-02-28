//
//  CommandBar.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct CommandBar: View {
    @Binding var selectedModel: String
    @State var chatCache = ChatCache.shared
    @Binding var conversationID: UUID
    @Binding var secondaryAccentColor: Color

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
                Button("Add content (not yet implemented)", systemImage: "plus") {
                    
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                /*Button("Simulate message flow", systemImage: "ant") {
                    appendDummyMessages()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)*/

                ToolsButton()

                if horizontalSizeClass == .compact{
                    Spacer()
                }

                ModelPicker(selectedModel: $selectedModel)

                if horizontalSizeClass != .compact{
                    Spacer()
                }
            }
            .opacity(0.75)

            SendMessageButton(conversationID: $conversationID, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem, accentColor: $secondaryAccentColor)
        }
        .frame(maxHeight: 16)
    }
}

#Preview {
    //CommandBar()
}
