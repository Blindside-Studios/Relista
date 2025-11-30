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
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @State private var chatCache = ChatCache.shared

    @State private var scrollWithAnimation = true

    var body: some View {
        ZStack{
            GeometryReader { geo in
                let chat = chatCache.getChat(for: conversationID)

                ScrollViewReader { proxy in
                    ScrollView(.vertical){
                        VStack{
                            ForEach(chat.messages.sorted { $0.timeStamp < $1.timeStamp }){ message in
                                if(message.role == .assistant){
                                    MessageModel(message: message)
                                        .frame(minHeight: message.id == chat.messages.last!.id ? geo.size.height * 0.8 : 0)
                                        .id(message.id)
                                }
                                else if (message.role == .user || message.role == .system){
                                    MessageUser(message: message, availableWidth: geo.size.width)
                                        .frame(minHeight: message.id == chat.messages.last!.id ? geo.size.height * 0.8 : 0)
                                        .id(message.id)
                                        .onAppear(){
                                            withAnimation(.easeInOut(duration: scrollWithAnimation ? 0.35 : 0)) {
                                                proxy.scrollTo(chat.messages.last!.id)
                                            }
                                        }
                                }
                            }
                        }
                        // to center-align
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: 740)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        #if os(iOS)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                    }
                    .safeAreaBar(edge: .bottom, spacing: 0){
                        PromptField(conversationID: conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                    }
                    //.onChange(of: chat.id, chatChanged)
                    //.onChange(of: inputMessage, textChanged)
                }
            }
        }
    }
    
    //func chatChanged(){
    //    scrollWithAnimation = false
    //}
    //
    //func textChanged(){
    //    scrollWithAnimation = true
    //}
}

#Preview {
    //ChatWindow(conversation: Conversation(from: <#any Decoder#>))
}
