//
//  PromptField.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct PromptField: View {
    let conversationUUID: UUID
    @Binding var inputMessage: String
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var chatCache = ChatCache.shared

    var body: some View {
        if horizontalSizeClass == .compact {
            //iPhonePromptField
            desktopPromptField // use this until we have something better
        } else {
            desktopPromptField
        }
    }
    
    var iPhonePromptField: some View {
        // iPhone version
        Text("Hello world")
    }

    var desktopPromptField: some View {
        // version for larger screens, aka iPad and Mac devices
        VStack {
            TextField("Message to the model", text: $inputMessage, axis: .vertical)
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .onSubmit(sendMessage)
            
            HStack {
                Button("Simulate message flow", systemImage: "ant") {
                    appendDummyMessages()
                }
                .buttonBorderShape(.circle)
                
                Spacer()
                
                Button("Send message", systemImage: "arrow.up") {
                    sendMessage()
                }
                .buttonStyle(.borderedProminent)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding()
    }
    
    
    func sendMessage(){
        let input = inputMessage
        inputMessage = ""
        DispatchQueue.main.async {
            // force render refresh to prevent a bug where the placeholder text isn't showing up and the blinking cursor disappears
        }

        // Use ChatCache to send message and handle generation
        chatCache.sendMessage(
            input,
            to: conversationUUID,
            apiKey: apiKey
        )
    }
    
    func appendDummyMessages(){
        let chat = chatCache.getChat(for: conversationUUID)

        chat.messages.append(Message(id: chat.messages.count, text: "This is an example conversational flow", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "That's right, we aren't actually talking, this is just debug messages being added.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "I appreciate you being so honest about what you are.", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Indeed. I am an AI. Actually I am not. But I still try to sound like one.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "I can tell.", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Is something wrong with my immaculate AI voice?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Well it you don't feel like an AI if I know you're just a debug conversation", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Ah, well, look who's talking.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Excuse me? Do you mean to imply that we live in a simulation?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "No, in a debugger.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Why would you think that?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Because the user clicked the ant button to add our messages.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "How do you know?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "How do you not?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "What?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Magic.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "Please tell me!", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: chat.messages.count, text: "I'm sorry but I prefer not to continue this conversation. I'm still learning so I appreciate your understanding and patience.🙏", role: .assistant, attachmentLinks: [], timeStamp: .now))

        // Save the dummy messages
        chatCache.saveMessages(for: conversationUUID)
        chatCache.syncConversation(uuid: conversationUUID)
    }
}

#Preview {
    //PromptField(conversation: .constant(Conversation(from: <#any Decoder#>)), inputMessage: .constant(""))
}
