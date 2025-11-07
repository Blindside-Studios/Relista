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
    @State var selectedConversationUUID: UUID?

    // Rename dialog state
    @State var showingRenameDialog: Bool = false
    @State var conversationToRename: Conversation? = nil
    @State var renameText: String = ""

    // Delete confirmation state
    @State var showingDeleteConfirmation: Bool = false
    @State var conversationToDelete: Conversation? = nil

    var body: some View {
        NavigationSplitView {
            ScrollView{
                ForEach (chatCache.conversations) { conv in
                    HStack{
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedConversationUUID == conv.uuid ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, -4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv.uuid)
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
            if let uuid = selectedConversationUUID {
                ChatWindow(conversationUUID: uuid)
                    .toolbar(){
                        ToolbarItemGroup() {
                            Button("New chat", systemImage: "square.and.pencil"){
                                createNewConversation()
                            }
                        }
                    }
            } else {
                Text("Select a conversation or create a new one")
                    .toolbar(){
                        ToolbarItemGroup() {
                            Button("New chat", systemImage: "square.and.pencil"){
                                createNewConversation()
                            }
                        }
                    }
            }
        }
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
    
    func createNewConversation() {
        // Unmark previous conversation as being viewed
        if let previousUUID = selectedConversationUUID {
            chatCache.setViewing(uuid: previousUUID, isViewing: false)
        }

        // Create new conversation
        let newConversation = chatCache.createConversation()
        selectedConversationUUID = newConversation.uuid

        // Mark new conversation as being viewed
        chatCache.setViewing(uuid: newConversation.uuid, isViewing: true)
    }

    func loadConversation(_ uuid: UUID) {
        // Unmark previous conversation as being viewed
        if let previousUUID = selectedConversationUUID {
            chatCache.setViewing(uuid: previousUUID, isViewing: false)
        }

        // Switch to new conversation
        selectedConversationUUID = uuid

        // Mark new conversation as being viewed (this loads it into cache)
        chatCache.setViewing(uuid: uuid, isViewing: true)
    }

    func renameConversation() {
        guard let conv = conversationToRename, !renameText.isEmpty else { return }

        chatCache.renameConversation(uuid: conv.uuid, to: renameText)

        // Clean up state
        conversationToRename = nil
        renameText = ""
    }

    func deleteConversation() {
        guard let conv = conversationToDelete else { return }

        // If we're deleting the currently selected conversation, clear selection
        if selectedConversationUUID == conv.uuid {
            selectedConversationUUID = nil
        }

        // Delete from cache and disk
        chatCache.deleteConversation(uuid: conv.uuid)

        // Clean up state
        conversationToDelete = nil
    }
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
