//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
    @State var showingSettings: Bool = false
    
    var body: some View {
        NavigationSplitView {
            List {
                Text("Chat history coming soon...")
            }
            .navigationTitle("Chats")
        } detail: {
            // Chat view
            ChatWindow()
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
}

#Preview {
    ContentView()
}
