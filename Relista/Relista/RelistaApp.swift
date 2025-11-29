//
//  RelistaApp.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

@main
struct RelistaApp: App {
    @State private var hasInitialized = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Only initialize once
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        await ModelList.loadModels()

                        // Perform initial CloudKit sync
                        do {
                            try await CloudKitSyncManager.shared.performFullSync()
                        } catch {
                            print("CloudKit sync error: \(error)")
                        }
                    }
                }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
