//
//  APIProvider.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

struct APIProvider: View {
    @AppStorage("APIKeyMistral") private var apiKeyMistral: String = ""
    @AppStorage("APIKeyClaude") private var apiKeyClaude: String = ""
    @AppStorage("APIKeyOpenRouter") private var apiKeyOpenRouter: String = ""
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Mistral API Key", text: $apiKeyMistral)
                    .textFieldStyle(.roundedBorder)
                SecureField("Claude API Key", text: $apiKeyClaude)
                    .textFieldStyle(.roundedBorder)
                /*SecureField("OpenRouter API Key", text: $apiKeyOpenRouter)
                    .textFieldStyle(.roundedBorder)*/
                
            }
            .padding()
        }
    }
}

#Preview {
    APIProvider()
}
