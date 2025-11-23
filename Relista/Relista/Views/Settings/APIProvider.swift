//
//  APIProvider.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

struct APIProvider: View {
    //@AppStorage("APIKeyMistral") private var apiKeyMistral: String = ""
    @AppStorage("APIKeyOpenRouter") private var apiKeyOpenRouter: String = ""
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("OpenRouter API Key", text: $apiKeyOpenRouter)
                    .textFieldStyle(.roundedBorder)
                //SecureField("Mistral API Key", text: $apiKeyMistral)
                //    .textFieldStyle(.roundedBorder)
            }
            .padding()
        }
    }
}

#Preview {
    APIProvider()
}
