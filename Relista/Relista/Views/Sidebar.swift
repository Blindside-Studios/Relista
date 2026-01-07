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
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String

    // Rename dialog state
    @State var showingRenameDialog: Bool = false
    @State var conversationToRename: Conversation? = nil
    @State var renameText: String = ""

    // Delete confirmation state
    @State var showingDeleteConfirmation: Bool = false
    @State var conversationToDelete: Conversation? = nil

    @ObservedObject private var agentManager = AgentManager.shared
    @ObservedObject private var syncManager = CloudKitSyncManager.shared

    @AppStorage("CustomAgentsInSidebarAreExpanded") private var showCustomAgents: Bool = true

    @Environment(\.onSidebarSelection) private var onSidebarSelection

    var body: some View {
        let currentConversation = chatCache.conversations.first { $0.id == selectedConversationID }
        let isCurrentEmpty = currentConversation?.hasMessages == false

        return ScrollView {
            LazyVStack(spacing: 0) {
                
                HStack {
                    Text("🐙 New chat")
                    Spacer()
                }
                .padding(10)
                .background {
                    if isCurrentEmpty && selectedAgent == nil {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .glassEffect(in: .rect(cornerRadius: 16.0))
                            .transition(.opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100)))
                    }
                }
                .animation(.default, value: isCurrentEmpty)
                .animation(.default, value: selectedAgent)
                //.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedConversationID = ConversationManager.createNewConversation(
                        fromID: selectedConversationID
                    ).newChatUUID
                    selectedAgent = nil
                    onSidebarSelection?()
                }
                
                if showCustomAgents{
                    ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                        let isCurrentAgent = selectedAgent == agent.id
                        
                        HStack {
                            Text(agent.icon + " " + agent.name)
                            Spacer()
                        }
                        .padding(10)
                        .background {
                            if isCurrentEmpty && isCurrentAgent {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .transition(.opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100)))
                            }
                        }
                        .animation(.bouncy, value: isCurrentEmpty)
                        .animation(.bouncy, value: isCurrentAgent)
                        //.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let result = ConversationManager.createNewConversation(
                                fromID: selectedConversationID,
                                withAgent: agent.id
                            )
                            selectedConversationID = result.newChatUUID
                            selectedAgent = agent.id
                            if !agent.model.isEmpty { selectedModel = agent.model }
                            onSidebarSelection?()
                        }
                    }
                }
                Button{
                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                        showCustomAgents.toggle()
                    }
                } label: {
                    HStack{
                        Label("Expand/collapse Squidlet list", systemImage: "chevron.down")
                            .rotationEffect(showCustomAgents ? Angle(degrees: -180) : Angle(degrees: 0))
                            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showCustomAgents)
                        Text("Squidlets")
                        Spacer()
                    }
                    .padding(10)
                }
                .opacity(0.8)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .backgroundStyle(.clear)
                
                Divider()
                    .padding(8)
                
                ForEach(
                    chatCache.conversations
                        .filter { $0.hasMessages && !$0.isArchived }
                        .sorted { a, b in
                            a.lastInteracted > b.lastInteracted
                        },
                    id: \.id
                ) { conv in
                    HStack {
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(10)
                    .background {
                        if selectedConversationID == conv.id {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                                .transition(.opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100)))
                        }
                    }
                    .animation(.bouncy, value: selectedConversationID)
                    //.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv.id)
                        if (conv.agentUsed != nil){
                            let agent = AgentManager.getAgent(fromUUID: conv.agentUsed!)
                            if agent != nil { selectedAgent = agent!.id }
                            else {selectedAgent = nil}
                        }
                        else { selectedAgent = nil }
                        selectedModel = conv.modelUsed
                        onSidebarSelection?()
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
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showCustomAgents)
            //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: chatCache.conversations)
            //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: agentManager.customAgents)
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
            .padding(8)
        }
        .refreshable {
            await performSync()
        }
        #if os(iOS)
        .safeAreaBar(edge: .bottom, spacing: 0){
            HStack{
                Spacer()
                Button {
                    showingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
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
                .buttonStyle(.plain)
                .padding()
                .glassEffect()
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
        // Pull latest messages from CloudKit in background
        chatCache.pullMessagesIfNeeded(for: id)
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
