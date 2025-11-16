//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
    @State var showingSettings: Bool = false
    @State var chatCache = ChatCache.shared
    @State var selectedConversationID: UUID? = ConversationManager.createNewConversation(fromID: nil)
    @State var inputMessage = "" // put this here so switching between layouts doesn't clear it
    
    @State private var columnVisibility: NavigationSplitViewVisibility = {
            #if os(iOS)
            return .detailOnly
            #else
            return .all
            #endif
        }()

    var body: some View {
        UnifiedSplitView {
            Sidebar(showingSettings: $showingSettings, chatCache: $chatCache, selectedConversationID: $selectedConversationID)
        } content: {
            if let id = selectedConversationID {
                ChatWindow(conversationID: id, inputMessage: $inputMessage)
                    .toolbar(){
                        ToolbarItemGroup() {
                            Button("New chat", systemImage: "square.and.pencil"){
                                selectedConversationID = ConversationManager.createNewConversation(fromID: selectedConversationID)
                            }
                        }
                    }
            }
        }
    }
}






/*
 // for later when adding settings to iOS
 #if os(iOS)
.toolbar {
    ToolbarItem(placement: .navigation) {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape")
        }
    }
}
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
#endif*/

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
