//
//  ChatWindow.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ChatWindow: View {
    @State var messageList: [Message] = []
    @State var apiKey: String = ""
    @State var inputMessage: String = ""
    //@State var outputMessage: String = ""
    
    var body: some View {
        ZStack{
            ScrollView(.vertical){
                ForEach(messageList){ message in
                    if(message.role == .assistant){
                        HStack{
                            Text(message.text)
                            Spacer()
                                .frame(minWidth: 50)
                        }
                        .padding()
                    }
                    else if (message.role == .user){
                        HStack{
                            Spacer()
                                .frame(minWidth: 50)
                            Text(message.text)
                        }
                        .padding()
                    }
                }
            }
            
            VStack{
                Spacer()
                VStack{
                    HStack{
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
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
                            inputMessage = "" //clear input
                            // make the magic happen
                            Task {
                                do {
                                    let service = MistralService(apiKey: apiKey)
                                    let outputMessage = try await service.sendMessage(input)
                                    let completion = Message(id: messageList.count, text: outputMessage, role: .assistant)
                                    messageList.append(completion)
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
            }
        }
        .padding()
    }
}

#Preview {
    ChatWindow()
}
