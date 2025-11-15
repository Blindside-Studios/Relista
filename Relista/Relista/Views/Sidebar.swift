//
//  Sidebar.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct Sidebar: View {
    @Binding var showingSettings: Bool
    @Binding var chatCache: ChatCache
    @Binding var selectedConversationID: UUID?

    // Rename dialog state
    @State var showingRenameDialog: Bool = false
    @State var conversationToRename: Conversation? = nil
    @State var renameText: String = ""

    // Delete confirmation state
    @State var showingDeleteConfirmation: Bool = false
    @State var conversationToDelete: Conversation? = nil
    
    var body: some View {
        ScrollView{
            VStack(spacing: 0){
                HStack{
                    Text("🐙 New chat")
                    Spacer()
                }
                .padding(8)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedConversationID = ConversationManager.createNewConversation(fromID: selectedConversationID)
                }
                
                Divider()
                    .padding(8)
                
                ForEach (chatCache.conversations.filter { $0.hasMessages && !$0.isArchived }) { conv in
                    HStack{
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedConversationID == conv.id ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv.id)
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
        }
        .padding(8)
    }

    func loadConversation(_ id: UUID) {
        // If switching away from a conversation without messages, delete it
        if let previousID = selectedConversationID {
            chatCache.setViewing(id: previousID, isViewing: false)
            if let previousConv = chatCache.getConversation(for: selectedConversationID!),
               !previousConv.hasMessages {
                chatCache.deleteConversation(id: selectedConversationID!)
            }
        }

        // Switch to new conversation
        selectedConversationID = id

        // Mark new conversation as being viewed (this loads it into cache)
        chatCache.setViewing(id: id, isViewing: true)
    }

    func renameConversation() {
        guard let conv = conversationToRename, !renameText.isEmpty else { return }

        chatCache.renameConversation(id: conv.id, to: renameText)

        // Clean up state
        conversationToRename = nil
        renameText = ""
    }

    func deleteConversation() {
        guard let conv = conversationToDelete else { return }

        // If we're deleting the currently selected conversation, clear selection
        if selectedConversationID == conv.id {
            selectedConversationID = nil
        }

        // Delete from cache and disk
        chatCache.deleteConversation(id: conv.id)

        // Clean up state
        conversationToDelete = nil
    }
}

#Preview {
    //Sidebar(showingSettings: .constant(false), chatCache: .constant(nil), selectedConversationID: .constant(nil))
}
