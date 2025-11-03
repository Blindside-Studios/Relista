//
//  PromptField.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct PromptField: View {
    @Bindable var conversation: Conversation
    @Binding var inputMessage: String
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
    var onConversationChanged: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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

        let userMsg = Message(id: conversation.messages.count, text: input, role: .user, attachmentLinks: [], timeStamp: .now)
        conversation.messages.append(userMsg)

        Task {
            do {
                let service = MistralService(apiKey: apiKey)
                let stream = try await service.streamMessage(messages: conversation.messages)

                // create a blank assistant message to stream to
                let assistantMsg = Message(id: conversation.messages.count, text: "", role: .assistant, attachmentLinks: [], timeStamp: .now)
                conversation.messages.append(assistantMsg)
                let assistantIndex = conversation.messages.count - 1

                for try await chunk in stream {
                    // Reassign to trigger Observable updates
                    var updatedMessage = conversation.messages[assistantIndex]
                    updatedMessage.text += chunk
                    conversation.messages[assistantIndex] = updatedMessage
                }

                // ADDED: Save after streaming completes
                conversation.lastInteracted = Date.now
                try ConversationManager.saveMessages(for: conversation)

                // Notify parent to sync conversation to index
                onConversationChanged()

            } catch {
                debugPrint("Error: \(error)")
                print("Full error: \(error.localizedDescription)")
            }
        }
    }
    
    func appendDummyMessages(){
        conversation.messages.append(Message(id: conversation.messages.count, text: "This is an example conversational flow", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "That's right, we aren't actually talking, this is just debug messages being added.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "I appreciate you being so honest about what you are.", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Indeed. I am an AI. Actually I am not. But I still try to sound like one.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "I can tell.", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Is something wrong with my immaculate AI voice?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Well it you don't feel like an AI if I know you're just a debug conversation", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Ah, well, look who's talking.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Excuse me? Do you mean to imply that we live in a simulation?", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "No, in a debugger.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Why would you think that?", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Because the user clicked the ant button to add our messages.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "How do you know?", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "How do you not?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "What?", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Magic.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "Please tell me!", role: .user, attachmentLinks: [], timeStamp: .now))
        conversation.messages.append(Message(id: conversation.messages.count, text: "I'm sorry but I prefer not to continue this conversation. I'm still learning so I appreciate your understanding and patience.🙏", role: .assistant, attachmentLinks: [], timeStamp: .now))
    }
}

#Preview {
    //PromptField(conversation: .constant(Conversation(from: <#any Decoder#>)), inputMessage: .constant(""))
}
