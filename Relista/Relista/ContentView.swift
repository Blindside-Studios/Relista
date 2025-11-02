//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
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
    }
}

#Preview {
    ContentView()
}
