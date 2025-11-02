//
//  PromptField.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct PromptField: View {
    @Binding var messageList: [Message]
    @Binding var inputMessage: String
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
    
    var body: some View {
        #if os(iOS)
        return iPhonePromptField
        #else
        return desktopPromptField
        #endif
    }
    
    var iPhonePromptField: some View {
        // iPhone version
        Text("Hello world")
    }

    var desktopPromptField: some View {
        // version for larger screens, aka iPad and Mac devices
        VStack{
            HStack{
                Button("Simulate message flow", systemImage: "ant"){
                    messageList.append(Message(id: messageList.count, text: "This is an example conversational flow", role: .user))
                    messageList.append(Message(id: messageList.count, text: "That's right, we aren't actually talking, this is just debug messages being added.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "I appreciate you being so honest about what you are.", role: .user))
                    messageList.append(Message(id: messageList.count, text: "Indeed. I am an AI. Actually I am not. But I still try to sound like one.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "I can tell.", role: .user))
                    messageList.append(Message(id: messageList.count, text: "Is something wrong with my immaculate AI voice?", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "Well it you don't feel like an AI if I know you're just a debug conversation", role: .user))
                    messageList.append(Message(id: messageList.count, text: "Ah, well, look who's talking.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "Excuse me? Do you mean to imply that we live in a simulation?", role: .user))
                    messageList.append(Message(id: messageList.count, text: "No, in a debugger.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "Why would you think that?", role: .user))
                    messageList.append(Message(id: messageList.count, text: "Because the user clicked the ant button to add our messages.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "How do you know?", role: .user))
                    messageList.append(Message(id: messageList.count, text: "How do you not?", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "What?", role: .user))
                    messageList.append(Message(id: messageList.count, text: "Magic.", role: .assistant))
                    messageList.append(Message(id: messageList.count, text: "Please tell me!", role: .user))
                    messageList.append(Message(id: messageList.count, text: "I'm sorry but I prefer not to continue this conversation. I'm still learning so I appreciate your understanding and patience.🙏", role: .assistant))
                }
                .frame(width: 30, height: 30)
                .buttonStyle(.glass)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            }
            HStack{
                TextField("Message to the model" , text: $inputMessage)
                    .textFieldStyle(.roundedBorder)
                Button("Send message", systemImage: "arrow.up"){
                    let input = inputMessage
                    messageList.append(Message(id: messageList.count, text: input, role: .user))
                    inputMessage = ""
                    
                    let assistantMsg = Message(id: messageList.count, text: "", role: .assistant)
                    messageList.append(assistantMsg)
                    let assistantIndex = messageList.count - 1
                    
                    Task {
                        do {
                            let service = MistralService(apiKey: apiKey)
                            let stream = try await service.streamMessage(input)
                            
                            for try await chunk in stream {
                                messageList[assistantIndex].text += chunk
                            }
                        } catch {
                            debugPrint("Error: \(error)")
                        }
                    }
                }
                .frame(width: 30, height: 30)
                .buttonStyle(.glass)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            }
        }
        .padding()
    }
}

#Preview {
    PromptField(messageList: .constant([]), inputMessage: .constant(""))
}
