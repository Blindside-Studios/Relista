//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
    @State var apiKey: String = ""
    @State var inputMessage: String = ""
    @State var outputMessage: String = ""
    
    var body: some View {
        VStack {
            Text("API Key")
            TextField("API Key", text: $apiKey)
            Text("Message to the model")
            TextField("Message to the model" , text: $inputMessage)
            Button("Send to model"){
                let input = inputMessage
                inputMessage = "" //clear input
                outputMessage = "" //clear output to indicate we are working
                // make the magic happen
                Task {
                        do {
                            let service = MistralService(apiKey: apiKey)
                            outputMessage = try await service.sendMessage(input)
                        } catch {
                            outputMessage = "Error: \(error)"
                        }
                    }
            }
            Text("Model response")
            TextField("Message from the API", text: $outputMessage)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
