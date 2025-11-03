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

    // Rename dialog state
    @State var showingRenameDialog: Bool = false
    @State var conversationToRename: Conversation? = nil
    @State var renameText: String = ""

    // Delete confirmation state
    @State var showingDeleteConfirmation: Bool = false
    @State var conversationToDelete: Conversation? = nil

    // Helper to sync conversation - can be called from child views
    func syncConversation() {
        syncSelectedConversation()
    }

    var body: some View {
        NavigationSplitView {
            ScrollView{
                ForEach (conversations) { conv in
                    HStack{
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedConversation === conv ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, -4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv)
                    }
                    .contextMenu {
                        Button {
                            conversationToRename = conv
                            renameText = conv.title
                            showingRenameDialog = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            conversationToDelete = conv
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Chats")
        } detail: {
            ChatWindow(conversation: selectedConversation, onConversationChanged: syncSelectedConversation)
                .toolbar(){
                    ToolbarItemGroup() {
                        Button("New chat", systemImage: "square.and.pencil"){
                            selectedConversation = Conversation(id: 0, title: "New Conversation", uuid: UUID(), messages: [], lastInteracted: Date.now, modelUsed: "ministral-3b-latest", isArchived: false)
                        }
                    }
                }
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
        .alert("Rename Conversation", isPresented: $showingRenameDialog) {
            TextField("Conversation Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                conversationToRename = nil
                renameText = ""
            }
            Button("Rename") {
                renameConversation()
            }
        } message: {
            Text("Enter a new name for this conversation")
        }
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }

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
            // Since Conversation is now a class, we directly modify it
            conv.messages = try ConversationManager.loadMessages(for: conv.uuid)
            selectedConversation = conv
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    func syncSelectedConversation(){
        if selectedConversation.messages.count > 0 { // do not attempt to save when the conversation is blank
            if let index = conversations.firstIndex(where: { $0.uuid == selectedConversation.uuid }) {
                // Since it's a class, the conversation in the array is already updated by reference
                // We just need to ensure the reference is correct
                if conversations[index] !== selectedConversation {
                    conversations[index] = selectedConversation
                }
            } else {
                // New conversation - add to list
                // Find highest existing id and add 1 to never assign an id twice
                let maxId = conversations.map { $0.id }.max() ?? -1
                selectedConversation.id = maxId + 1
                if selectedConversation.messages.count > 0 { selectedConversation.title = selectedConversation.messages[0].text }
                conversations.append(selectedConversation)
            }

            // Save index
            do {
                try ConversationManager.saveIndex(conversations: conversations)
            } catch {
                print("Error saving index: \(error)")
            }
        }
    }

    func renameConversation() {
        guard let conv = conversationToRename, !renameText.isEmpty else { return }

        conv.title = renameText
        
        if selectedConversation === conv {
            selectedConversation.title = renameText
        }

        // Save index with updated title
        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving renamed conversation: \(error)")
        }

        // Clean up state
        conversationToRename = nil
        renameText = ""
    }

    func deleteConversation() {
        guard let conv = conversationToDelete else { return }

        // Remove from conversations array
        if let index = conversations.firstIndex(where: { $0.uuid == conv.uuid }) {
            conversations.remove(at: index)
        }

        // If we're deleting the currently selected conversation, switch to default
        if selectedConversation === conv {
            selectedConversation = Conversation(id: 0, title: "New Conversation", uuid: UUID(), messages: [], lastInteracted: Date.now, modelUsed: "ministral-3b-latest", isArchived: false)
        }

        // Delete from disk
        do {
            try ConversationManager.deleteConversation(uuid: conv.uuid)
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error deleting conversation: \(error)")
        }

        // Clean up state
        conversationToDelete = nil
    }
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
