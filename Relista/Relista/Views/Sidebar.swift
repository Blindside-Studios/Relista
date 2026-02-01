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
                            .transition(
                                hSizeClass == .compact
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                            )
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
                                    .transition(
                                        hSizeClass == .compact
                                        ? .opacity
                                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                                    )
                            }
                        }
                        .animation(.default, value: isCurrentEmpty)
                        .animation(.default, value: isCurrentAgent)
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
                            //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showCustomAgents)
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
                
                HStack(alignment: .center){
                    Menu {
                        Section("Show") {
                            ForEach(ChatKind.allCases, id: \.self) { kind in
                                Button {
                                    chatFilter = .kind(kind)
                                } label: {
                                    if case .kind(kind) = chatFilter {
                                        Label(kind.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(kind.rawValue)
                                    }
                                }
                            }
                        }

                        if !agentManager.customAgents.isEmpty {
                            Section("By Squidlet") {
                                ForEach(agentManager.customAgents) { agent in
                                    Button {
                                        chatFilter = .agent(agent.id)
                                    } label: {
                                        if case .agent(agent.id) = chatFilter {
                                            Label(agent.icon + " " + agent.name, systemImage: "checkmark")
                                        } else {
                                            Text(agent.icon + " " + agent.name)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(chatFilterLabel)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .opacity(0.7)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
                    VStack{
                        if !ChatCache.shared.isLoading{
                            Divider()
                                .padding(4)
                        }
                        else{
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
                            //await performSync()
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
                
                if chatFilter != .kind(.hideChats) {
                    ForEach(
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
                                    .transition(
                                        hSizeClass == .compact
                                        ? .opacity
                                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                                    )
                            }
                        }
                        .animation(.default, value: selectedConversationID)
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
            }
            .animation(.default, value: showChats)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: showCustomAgents)
            //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: chatCache.conversations)
            //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: agentManager.customAgents)
            //.navigationTitle("Chats")
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
                /*Button {
                    migrateDataToiCloud()
                } label: {
                    Label("Migrate", systemImage: "arrow.right.doc.on.clipboard")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding()
                .glassEffect()
                 */
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

    var chatFilterLabel: String {
        switch chatFilter {
        case .kind(let kind):
            return kind.rawValue
        case .agent(let agentID):
            if let agent = agentManager.customAgents.first(where: { $0.id == agentID }) {
                return agent.icon + " " + agent.name
            }
            return "Unknown Agent"
        }
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

enum ChatKind: String, CaseIterable, Codable {
    case recents = "Recents"
    case archived = "Archived"
    case hideChats = "Hide Chats"
}

enum ChatFilter: Hashable {
    case kind(ChatKind)
    case agent(UUID)
}

#Preview {
    //Sidebar(showingSettings: .constant(false), chatCache: .constant(nil), selectedConversationID: .constant(nil))
}
