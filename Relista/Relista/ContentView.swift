//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
    @State var showingSettings: Bool = false
    @State var conversations: [Conversation] = []
    @State var selectedConversation = Conversation(id: 0, title: "New Conversation", uuid: UUID(), messages: [], lastInteracted: Date.now, modelUsed: "mistral-3b-latest", isArchived: false)
    
    var body: some View {
        NavigationSplitView {
            ScrollView{
                ForEach (conversations) { conv in
                    HStack{
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedConversation == conv ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, -4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv)
                    }
                }
            }
            .navigationTitle("Chats")
        } detail: {
            ChatWindow(conversation: $selectedConversation)
        }
        .onAppear(){
            do {
                try ConversationManager.initializeStorage()
                conversations = try ConversationManager.loadIndex()
            } catch {
                print("Error loading: \(error)")
            }
        }
        .onChange(of: selectedConversation, syncSelectedConversation)
        
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
        #endif
    }
    
    func loadConversation(_ conv: Conversation) {
        do {
            var loadedConv = conv
            loadedConv.messages = try ConversationManager.loadMessages(for: conv.uuid)
            selectedConversation = loadedConv
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    func syncSelectedConversation(){
        if selectedConversation.messages.count > 0 { // do not attempt to save when the conversation is blank
            if let index = conversations.firstIndex(where: { $0.uuid == selectedConversation.uuid }) {
                // Update metadata only (not messages)
                var updatedConv = conversations[index]
                updatedConv.lastInteracted = selectedConversation.lastInteracted
                updatedConv.modelUsed = selectedConversation.modelUsed
                updatedConv.isArchived = selectedConversation.isArchived
                
                conversations[index] = updatedConv
            } else {
                // New conversation - add without messages
                var newConv = selectedConversation
                newConv.id = conversations.count
                newConv.messages = []  // don't add messages to sidebar list to save memory
                conversations.append(newConv)
            }
            
            // Save index
            do {
                try ConversationManager.saveIndex(conversations: conversations)
            } catch {
                print("Error saving index: \(error)")
            }
        }
    }
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
