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

    @ObservedObject private var agentManager = AgentManager.shared
    @ObservedObject private var syncManager = CloudKitSyncManager.shared

    var body: some View {
        let currentConversation = chatCache.conversations.first { $0.id == selectedConversationID }
        let isCurrentEmpty = currentConversation?.hasMessages == false

        return ScrollView {
            VStack(spacing: 0) {

                HStack {
                    Text("🐙 New chat")
                    Spacer()
                }
                .padding(8)
                .background {
                    if isCurrentEmpty && ChatCache.shared.selectedAgent == nil {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.thickMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedConversationID = ConversationManager.createNewConversation(
                        fromID: selectedConversationID
                    )
                    ChatCache.shared.selectedAgent = nil
                }
                
                ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                    let isCurrentAgent = ChatCache.shared.selectedAgent == agent.id

                    HStack {
                        Text(agent.icon + " " + agent.name)
                        Spacer()
                    }
                    .padding(8)
                    .background {
                        if isCurrentEmpty && isCurrentAgent {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.thickMaterial)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.clear)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedConversationID = ConversationManager.createNewConversation(
                            fromID: selectedConversationID,
                            withAgent: agent.id
                        )
                        ChatCache.shared.selectedAgent = agent.id
                        if agent.model != nil { ChatCache.shared.selectedModel = ModelList.Models.filter {$0.modelID == agent.model! }.first! }
                    }
                }
                                
                Divider()
                    .padding(8)
                
                ForEach(
                    chatCache.conversations
                            .filter { $0.hasMessages && !$0.isArchived }
                            .sorted { a, b in
                                a.lastInteracted > b.lastInteracted
                            }
                ) { conv in
                    HStack {
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background {
                        if selectedConversationID == conv.id {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.thickMaterial)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.clear)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv.id)
                        if (conv.agentUsed != nil){
                            let agent = AgentManager.getAgent(fromUUID: conv.agentUsed!)
                            if agent != nil { ChatCache.shared.selectedAgent = agent!.id }
                        }
                        let possibleModels = ModelList.Models.filter { $0.modelID == conv.modelUsed }
                        if (possibleModels.count > 0){
                            ChatCache.shared.selectedModel = possibleModels.first!
                        }
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
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if syncManager.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            Task {
                                await performSync()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }
            #endif
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
        .refreshable {
            await performSync()
        }
        .padding(8)
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0){
            HStack{
                Button {
                    showingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack{
                        SettingsView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(role: .close){
                                        showingSettings = false
                                    }
                                }
                            }
                            .navigationTitle("Settings")
                    }
                }
                Spacer()
            }
        }
        #endif
    }

    func loadConversation(_ id: UUID) {
        if let previousID = selectedConversationID {
            chatCache.setViewing(id: previousID, isViewing: false)
            if let previousConv = chatCache.getConversation(for: previousID),
               !previousConv.hasMessages {
                chatCache.deleteConversation(id: previousID)
            }
        }

        selectedConversationID = id
        chatCache.setViewing(id: id, isViewing: true)
    }

    func renameConversation() {
        guard let conv = conversationToRename, !renameText.isEmpty else { return }
        chatCache.renameConversation(id: conv.id, to: renameText)
        conversationToRename = nil
        renameText = ""
    }

    func deleteConversation() {
        guard let conv = conversationToDelete else { return }
        if selectedConversationID == conv.id {
            selectedConversationID = nil
        }
        chatCache.deleteConversation(id: conv.id)
        conversationToDelete = nil
    }

    func performSync() async {
        do {
            try await CloudKitSyncManager.shared.performFullSync()
        } catch {
            print("Sync error: \(error)")
        }
    }
}

#Preview {
    //Sidebar(showingSettings: .constant(false), chatCache: .constant(nil), selectedConversationID: .constant(nil))
}
