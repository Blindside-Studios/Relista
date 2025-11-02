//
//  SettingsView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
        
        var body: some View {
            Form {
                Section("API Keys") {
                    SecureField("Mistral API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
            }
            #if os(macOS)
            .frame(width: 450, height: 200)
            #endif
        }
}

#Preview {
    SettingsView()
}
