//
//  PromptField.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct PromptField: View {
    @State var showModelPickerSheet = false
    @State var showModelPickerPopOver = false
    let conversationID: UUID
    @Binding var inputMessage: String
    @AppStorage("APIKeyOpenRouter") private var apiKey: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var chatCache = ChatCache.shared
    
    @Namespace private var MessageOptionsTransition

    var body: some View {
        VStack(spacing: 12) {
            TextField("Message to the model", text: $inputMessage, axis: .vertical)
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .onSubmit(sendMessage)
            
            HStack(spacing: 12) {
                Group{
                    Button("Simulate message flow", systemImage: "ant") {
                        appendDummyMessages()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    
                    Button{
                        if horizontalSizeClass == .compact { showModelPickerSheet = true }
                        else { showModelPickerPopOver.toggle() }
                    } label: {
                        VStack(alignment: .center, spacing: -2) {
                            if let family = ChatCache.shared.selectedModel.family,
                               let spec = ChatCache.shared.selectedModel.specifier {
                                
                                Text(family)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text(spec)
                                    .font(.caption)
                            } else {
                                Text(ChatCache.shared.selectedModel.name)
                                    .font(.caption)
                            }
                        }
                        .bold()
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.titleOnly)
                    .matchedTransitionSource(
                        id: "model", in: MessageOptionsTransition
                    )
                    .popover(isPresented: $showModelPickerPopOver) {
                        ModelPicker(
                            selectedModel: Binding(
                                get: { ChatCache.shared.selectedModel },
                                set: { ChatCache.shared.selectedModel = $0 }
                            ),
                            isOpen: $showModelPickerPopOver
                        )
                        .frame(minWidth: 250, maxHeight: 450)
                    }
                }
                .opacity(0.75)
                
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
        .glassEffect(in: .rect(cornerRadius: 18))
        // to center-align
        .frame(maxWidth: .infinity)
        .frame(maxWidth: 750)
        .frame(maxWidth: .infinity)
        .padding(8)
        
        #if os(iOS) // only show this on iOS because the other platforms use a popover
        .sheet(isPresented: $showModelPickerSheet) {
            ModelPicker(
                selectedModel: Binding(
                    get: { ChatCache.shared.selectedModel },
                    set: { ChatCache.shared.selectedModel = $0 }
                ),
                isOpen: $showModelPickerPopOver
            )
                .presentationDetents([.medium, .large])
            
                .navigationTransition(
                    .zoom(sourceID: "model", in: MessageOptionsTransition)
                )
        }
        #endif
        /*if horizontalSizeClass == .compact {
            //iPhonePromptField
            desktopPromptField // use this until we have something better
        } else {
            desktopPromptField
        }*/
    }
    
    
    func sendMessage(){
        let input = inputMessage
        inputMessage = ""
        DispatchQueue.main.async {
            // force render refresh to prevent a bug where the placeholder text isn't showing up and the blinking cursor disappears
        }

        // Use ChatCache to send message and handle generation
        chatCache.sendMessage(
            modelName: ChatCache.shared.selectedModel.modelID,
            inputText: input,
            to: conversationID,
            apiKey: apiKey
        )
    }

    func appendDummyMessages(){
        let chat = chatCache.getChat(for: conversationID)

        chat.messages.append(Message(id: UUID(), text: "This is an example conversational flow", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "That's right, we aren't actually talking, this is just debug messages being added.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "I appreciate you being so honest about what you are.", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Indeed. I am an AI. Actually I am not. But I still try to sound like one.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "I can tell.", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Is something wrong with my immaculate AI voice?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Well it you don't feel like an AI if I know you're just a debug conversation", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Ah, well, look who's talking.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Excuse me? Do you mean to imply that we live in a simulation?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "No, in a debugger.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Why would you think that?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Because the user clicked the ant button to add our messages.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "How do you know?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "How do you not?", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "What?", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Magic.", role: .assistant, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "Please tell me!", role: .user, attachmentLinks: [], timeStamp: .now))
        chat.messages.append(Message(id: UUID(), text: "I'm sorry but I prefer not to continue this conversation. I'm still learning so I appreciate your understanding and patience.🙏", role: .assistant, attachmentLinks: [], timeStamp: .now))

        // Save the dummy messages
        chatCache.saveMessages(for: conversationID)
        chatCache.syncConversation(id: conversationID)
    }
}

#Preview {
    //PromptField(conversation: .constant(Conversation(from: <#any Decoder#>)), inputMessage: .constant(""))
}
