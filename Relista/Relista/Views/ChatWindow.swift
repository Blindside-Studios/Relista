//
//  ChatWindow.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ChatWindow: View {
    @State var messageList: [Message] = []
    @State var inputMessage: String = ""
    
    var body: some View {
        ZStack{
            GeometryReader { geo in
                ScrollView(.vertical){
                    ForEach(messageList){ message in
                        if(message.role == .assistant){
                            MessageModel(messageText: message.text)
                        }
                        else if (message.role == .user){
                            MessageUser(messageText: message.text, availableWidth: geo.size.width)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0){
                    PromptField(messageList: $messageList, inputMessage: $inputMessage)
                }
            }
        }
    }
}

#Preview {
    ChatWindow()
}
