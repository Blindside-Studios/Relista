//
//  ChatWindow.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ChatWindow: View {
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @State private var chatCache = ChatCache.shared
    
    @Binding var useSearch: Bool
    @Binding var useReasoning: Bool

    @State private var scrollWithAnimation = true

    var body: some View {
        ZStack{
            GeometryReader { geo in
                // Access chat directly from cache - it's loaded in .task
                if let chat = chatCache.loadedChats[conversationID] {
                    ScrollViewReader { proxy in
                    ScrollView(.vertical){
                        LazyVStack{
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
                        PromptField(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, useSearch: $useSearch, useReasoning: $useReasoning)
                    }
                    .onChange(of: conversationID) { _, _ in
                        // Scroll to bottom immediately when switching conversations
                        if let lastMessageID = chat.messages.last?.id {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                    .onChange(of: chat.messages.last?.id) { _, newLastMessageID in
                        guard let lastMessage = chat.messages.last,
                              lastMessage.role == .user || lastMessage.role == .system else {
                            return
                        }
                        withAnimation(.easeInOut(duration: scrollWithAnimation ? 0.35 : 0)) {
                            proxy.scrollTo(newLastMessageID)
                        }
                    }
                    }
                } else {
                    // Chat loading or not found
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: conversationID) {
            // Load the chat when the view appears or conversation changes
            _ = chatCache.getChat(for: conversationID)
            // Pull latest messages from CloudKit in background
            chatCache.pullMessagesIfNeeded(for: conversationID)
        }
        .navigationTitle(chatCache.getConversation(for: conversationID)?.title ?? "New chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
