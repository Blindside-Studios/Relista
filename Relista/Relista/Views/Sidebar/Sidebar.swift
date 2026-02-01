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
    @Binding var selectedConversationID: UUID
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    
    // Rename dialog state
    @State var showingRenameDialog: Bool = false
    @State var conversationToRename: Conversation? = nil
    @State var renameText: String = ""
    
    // Delete confirmation state
    @State var showingDeleteConfirmation: Bool = false
    @State var conversationToDelete: Conversation? = nil
    
    @State private var chatFilter: ChatFilter = .kind(.recents)
    
    @ObservedObject private var agentManager = AgentManager.shared
    
    @AppStorage("CustomAgentsInSidebarAreExpanded") private var showCustomAgents: Bool = true
    @AppStorage("ChatsInSidebarAreExpanded") private var showChats = true
    
    @Environment(\.onSidebarSelection) private var onSidebarSelection
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    let createNewChat: () -> Void
    let reloadSidebar: () async -> Void
    
    private var isCurrentEmpty: Bool {
        let currentConversation = chatCache.conversations.first { $0.id == selectedConversationID }
        return currentConversation?.hasMessages == false
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                newChatRow
                agentsList
                squidletsToggle
                filterHeader
                conversationsList
            }
            .animation(.default, value: showChats)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showCustomAgents)
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
        .safeAreaBar(edge: .bottom, spacing: 0) {
            settingsBar
        }
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private var newChatRow: some View {
        HStack {
            Text("🐙 New chat")
            Spacer()
        }
        .padding(10)
        .background {
            if isCurrentEmpty && selectedAgent == nil {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .transition(
                        hSizeClass == .compact
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                    )
            }
        }
        .animation(.default, value: isCurrentEmpty)
        .animation(.default, value: selectedAgent)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedConversationID = ConversationManager.createNewConversation(
                fromID: selectedConversationID
            ).newChatUUID
            selectedAgent = nil
            onSidebarSelection?()
        }
    }

    @ViewBuilder
    private var agentsList: some View {
        if showCustomAgents {
            ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                AgentRow(
                    agent: agent,
                    isSelected: selectedAgent == agent.id,
                    isCurrentEmpty: isCurrentEmpty
                ) {
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
    }

    @ViewBuilder
    private var squidletsToggle: some View {
        Button {
            withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                showCustomAgents.toggle()
            }
        } label: {
            HStack {
                Label("Expand/collapse Squidlet list", systemImage: "chevron.down")
                    .rotationEffect(showCustomAgents ? Angle(degrees: -180) : Angle(degrees: 0))
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
    }

    @ViewBuilder
    private var filterHeader: some View {
        HStack(alignment: .center) {
            ChatFilterMenu(
                chatFilter: $chatFilter,
                agentManager: agentManager
            )
            VStack {
                if !ChatCache.shared.isLoading {
                    Divider()
                        .padding(4)
                } else {
                    ProgressView(value: ChatCache.shared.loadingProgress)
                        .progressViewStyle(.linear)
                        .padding(4)
                }
            }
            .animation(.default, value: ChatCache.shared.isLoading)
            #if os(macOS)
            Button {
                Task {
                    await reloadSidebar()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .contentShape(Rectangle())
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0.5)
            .buttonStyle(.plain)
            .background(.clear)
            .controlSize(.small)
            .labelStyle(.iconOnly)
            .contentShape(Rectangle())
            #endif
        }
        .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showChats)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var conversationsList: some View {
        if chatFilter != .kind(.hideChats) {
            ForEach(filteredConversations, id: \.id) { conv in
                ConversationRow(
                    conversation: conv,
                    isSelected: selectedConversationID == conv.id,
                    onTap: {
                        loadConversation(conv.id)
                        if let agentUsed = conv.agentUsed,
                           let agent = AgentManager.getAgent(fromUUID: agentUsed) {
                            selectedAgent = agent.id
                        } else {
                            selectedAgent = nil
                        }
                        selectedModel = conv.modelUsed
                        onSidebarSelection?()
                    },
                    onRename: {
                        conversationToRename = conv
                        renameText = conv.title
                        showingRenameDialog = true
                    },
                    onDelete: {
                        conversationToDelete = conv
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var settingsBar: some View {
        HStack {
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gear")
                    .contentShape(Rectangle())
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .close) {
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
    
    func loadConversation(_ id: UUID) {
        let previousID = selectedConversationID
        chatCache.setViewing(id: previousID, isViewing: false)

        // Delete previous conversation if it was empty
        if let previousConv = chatCache.getConversation(for: previousID),
           !previousConv.hasMessages {
            chatCache.deleteConversation(id: previousID)
        }

        // Always update to the new conversation
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
            createNewChat()
        }
        chatCache.deleteConversation(id: conv.id)
        conversationToDelete = nil
    }
    
    func performSync() async {
        print("🔄 Manual refresh triggered (Sidebar)")
        await AgentManager.shared.refreshFromStorage()
        await ConversationManager.refreshConversationsFromStorage()
    }

    var filteredConversations: [Conversation] {
        chatCache.conversations
            .filter { conv in
                guard conv.hasMessages else { return false }
                switch chatFilter {
                case .kind(.recents):
                    return !conv.isArchived
                case .kind(.archived):
                    return conv.isArchived
                case .kind(.hideChats):
                    return false
                case .agent(let agentID):
                    return conv.agentUsed == agentID && !conv.isArchived
                }
            }
            .sorted { $0.lastInteracted > $1.lastInteracted }
    }

    func migrateDataToiCloud() {
        let fileManager = FileManager.default

        // Source: old local Documents/Relista folder
        let localDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localRelista = localDocuments.appendingPathComponent("Relista")

        // Destination: iCloud container
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") else {
            print("❌ iCloud container not available")
            return
        }
        let iCloudRelista = iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")

        print("📦 Migrating data...")
        print("  From: \(localRelista.path)")
        print("  To: \(iCloudRelista.path)")

        do {
            // Create destination if needed
            if !fileManager.fileExists(atPath: iCloudRelista.path) {
                try fileManager.createDirectory(at: iCloudRelista, withIntermediateDirectories: true)
            }

            // Copy all contents
            let contents = try fileManager.contentsOfDirectory(at: localRelista, includingPropertiesForKeys: nil)
            for item in contents {
                let destURL = iCloudRelista.appendingPathComponent(item.lastPathComponent)

                // Remove existing if present
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }

                try fileManager.copyItem(at: item, to: destURL)
                print("  ✓ Copied: \(item.lastPathComponent)")
            }

            print("✅ Migration complete! Refresh to see your data.")
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
}

#Preview {
    //Sidebar(showingSettings: .constant(false), chatCache: .constant(nil), selectedConversationID: .constant(nil))
}
