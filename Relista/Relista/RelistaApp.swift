//
//  RelistaApp.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

@main
struct RelistaApp: App {
    init() {
        Task {
            await ModelList.loadModels()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
