//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

// Notification for menu bar commands
extension Notification.Name {
    static let createNewChat = Notification.Name("createNewChat")
}

struct ContentView: View {
    @State var showingSettings: Bool = false
    @State var chatCache = ChatCache.shared
    @State var selectedConversationID: UUID? = ConversationManager.createNewConversation(fromID: nil).newChatUUID
    @State var inputMessage = "" // put this here so switching between layouts doesn't clear it
    
    @State var selectedAgent: UUID? = nil
    @State var selectedModel: String = ModelList.placeHolderModel
    
    @State private var columnVisibility: NavigationSplitViewVisibility = {
#if os(iOS)
        return .detailOnly
#else
        return .all
#endif
    }()
    
    var body: some View {
        UnifiedSplitView {
            Sidebar(showingSettings: $showingSettings, chatCache: $chatCache, selectedConversationID: $selectedConversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
        } content: {
            if let id = selectedConversationID {
                ChatWindow(conversationID: id, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                    .toolbar(){
                        ToolbarItemGroup() {
                            Button("New chat", systemImage: "square.and.pencil"){
                                createNewChat()
                            }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewChat)) { _ in
            createNewChat()
        }
    }
    
    private func createNewChat() {
        let prevChat = ChatCache.shared.conversations.first(where: { $0.id == selectedConversationID })
        debugPrint("prevChat != nil: \(prevChat != nil) prevChat.hasMessages: \(prevChat!.hasMessages)")
        let result = ConversationManager.createNewConversation(fromID: selectedConversationID, usingAgent: prevChat != nil && prevChat!.hasMessages, withAgent: selectedAgent)
        selectedConversationID = result.newChatUUID
        selectedAgent = result.newAgent
        if result.newAgent != nil {
            let agent = AgentManager.getAgent(fromUUID: result.newAgent!)
            if agent != nil {
                selectedModel = agent!.model
            }
        }
    }
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
