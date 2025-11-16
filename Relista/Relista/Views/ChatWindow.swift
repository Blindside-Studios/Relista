//
//  ChatWindow.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ChatWindow: View {
    let conversationID: UUID
    @Binding var inputMessage: String
    @State private var chatCache = ChatCache.shared

    var body: some View {
        ZStack{
            GeometryReader { geo in
                let chat = chatCache.getChat(for: conversationID)

                ScrollView(.vertical){
                    VStack{
                        ForEach(chat.messages){ message in
                            if(message.role == .assistant){
                                MessageModel(messageText: message.text)
                            }
                            else if (message.role == .user){
                                MessageUser(messageText: message.text, availableWidth: geo.size.width)
                            }
                        }
                    }
                    // to center-align
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: 740)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0){
                    PromptField(conversationID: conversationID, inputMessage: $inputMessage)
                }
            }
        }
    }
}

#Preview {
    //ChatWindow(conversation: Conversation(from: <#any Decoder#>))
}
