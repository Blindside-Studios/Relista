//
//  RelistaApp.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import Foundation

#if os(macOS)
struct TextSizeCommands: Commands {
    @AppStorage("chatFontSize") private var fontSize: Double = 13

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button("Make Text Bigger", systemImage: "textformat.size.larger") { fontSize = min(fontSize + 1, 24) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Make Text Smaller", systemImage: "textformat.size.smaller") { fontSize = max(fontSize - 1, 9) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Make Text Normal Size", systemImage: "textformat.size") { fontSize = 13 }
                .keyboardShortcut("0", modifiers: .command)
        }
    }
}
#endif

@main
struct RelistaApp: App {
    @State private var hasInitialized = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(reloadSidebar: refreshContent)
                .onAppear {
                    // Only initialize once
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        await ModelList.loadModels()
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        Task{
                            await refreshContent()
                        }
                    }
                }
        .commands {
            // Replace default "New Window" with "New Chat" in File menu
            #if os(macOS) || os(iOS)
            CommandGroup(replacing: .newItem) {
                Button("New Chat", systemImage: "square.and.pencil") {
                    NotificationCenter.default.post(name: .createNewChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            #endif

            // Add refresh command to View menu (macOS and iPadOS)
            #if os(macOS) || os(iOS)
            CommandGroup(after: .sidebar) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await refreshContent()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            #endif

            #if os(macOS)
            TextSizeCommands()
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
    
    func refreshContent() async{
        ChatCache.shared.loadingProgress = 0.0
        ChatCache.shared.isLoading = true
        print("Refreshing agents and chats")
        await ensureICloudUpToDate()
        await AgentManager.shared.refreshFromStorage()
        ChatCache.shared.loadingProgress = 0.9
        await ConversationManager.refreshConversationsFromStorage()
        ChatCache.shared.loadingProgress = 1.0
        ChatCache.shared.isLoading = false
    }
    
    func ensureICloudUpToDate() async {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") else {
            print("iCloud not available")
            return
        }
        
        let relistaURL = iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")
        
        let conversationIndexURL = relistaURL.appendingPathComponent("index.json")
        let agentsURL = relistaURL.appendingPathComponent("agents.json")
        
        ChatCache.shared.loadingProgress = 0.1
        
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: conversationIndexURL)
            try FileManager.default.startDownloadingUbiquitousItem(at: agentsURL)
            
            ChatCache.shared.loadingProgress = 0.2
            
            try await waitForDownload(url: conversationIndexURL)
            ChatCache.shared.loadingProgress = 0.5
            try await waitForDownload(url: agentsURL)
            ChatCache.shared.loadingProgress = 0.8
            
            print("✅ iCloud files are now current")
        } catch {
            print("❌ iCloud sync error: \(error)")
        }
    }

    private func waitForDownload(url: URL) async throws {
        while true {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                switch status {
                case .current:
                    print("✅ \(url.lastPathComponent) is current")
                    return
                case .downloaded:
                    print("⏳ \(url.lastPathComponent) downloaded, checking if current...")
                    break
                case .notDownloaded:
                    print("⬇️ \(url.lastPathComponent) downloading...")
                    break
                default:
                    break
                }
            }
            
            // man this is a weird solution
            try await Task.sleep(for: .milliseconds(100))
        }
    }}
