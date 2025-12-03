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
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @FocusState private var isTextFieldFocused: Bool
    @AppStorage("APIKeyOpenRouter") private var apiKey: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var chatCache = ChatCache.shared
    @State private var placeHolder = ChatPlaceHolders.returnRandomString()
    @State private var placeHolderVerb = ChatPlaceHolders.returnRandomVerb()

    @Namespace private var MessageOptionsTransition

    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true

    var body: some View {
        #if os(macOS)
        let spacing: CGFloat = 12
        #else
        let spacing: CGFloat = 16
        #endif
        VStack(spacing: spacing) {
            TextField(selectedAgent == nil ? placeHolder : "\(placeHolderVerb) @\(AgentManager.getUIAgentName(fromUUID: selectedAgent!))", text: $inputMessage, axis: .vertical)
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .onSubmit(sendMessage)
                .onKeyPress { keyPress in
                    if keyPress.modifiers == .shift
                        && keyPress.key == .return
                    {
                        inputMessage += "\n"
                        return .handled
                    } else {
                        return .ignored
                    }
                }
            
            HStack(spacing: spacing) {
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
                        let model = ModelList.getModelFromSlug(slug: selectedModel)
                        VStack(alignment: .center, spacing: -2) {
                            if let family = model.family,
                               let spec = model.specifier {

                                Text(family)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(spec)
                                    .font(.caption)
                            } else {
                                Text(model.name)
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
                            selectedModelSlug: $selectedModel,
                            isOpen: $showModelPickerPopOver
                        )
                        .frame(minWidth: 250, maxHeight: 450)
                    }
                }
                .opacity(0.75)
                
                Spacer()

                Button {
                    let chat = chatCache.getChat(for: conversationID)
                    if chat.isGenerating {
                        chatCache.cancelGeneration(for: conversationID)
                    } else {
                        sendMessage()
                    }
                } label: {
                    let chat = chatCache.getChat(for: conversationID)
                    ZStack{
                        Label("Stop generating", systemImage: "stop.fill")
                            .offset(y: chat.isGenerating ? 0 : 25)
                        Label("Send message", systemImage: "arrow.up")
                            .offset(y: chat.isGenerating ? -25 : 0)
                    }
                    .font(.headline)
                    // weirdly these seem to be interpreted differently across platforms
                    #if os(macOS)
                    .frame(width: 18, height: 18)
                    #else
                    .frame(width: 19, height: 19)
                    #endif
                    .animation(.bouncy(duration: 0.3, extraBounce: 0.15), value: chat.isGenerating)
                }
                .buttonStyle(.glassProminent)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .clipped()
                // weirdly these seem to be interpreted differently across platforms
                #if os(macOS)
                .offset(x: 7, y: 2)
                #else
                .offset(x: 15, y: 1)
                #endif
                .contextMenu {
                    Button {
                        sendMessageAsSystem()
                    } label: {
                        Label("Send as system message", systemImage: "exclamationmark.bubble")
                    }
                }
            }
            .frame(maxHeight: 16)
        }
        .padding(spacing)
        #if os(macOS)
        .glassEffect(in: .rect(cornerRadius: 18))
        #else
        .glassEffect(in: .rect(cornerRadius: 22))
        #endif
        // to center-align
        .frame(maxWidth: .infinity)
        .frame(maxWidth: 750)
        .frame(maxWidth: .infinity)
        .padding(8)
        
        #if os(iOS) // only show this on iOS because the other platforms use a popover
        .sheet(isPresented: $showModelPickerSheet) {
            ModelPicker(
                selectedModelSlug: $selectedModel,
                isOpen: $showModelPickerSheet
            )
                .presentationDetents([.medium, .large])

                .navigationTransition(
                    .zoom(sourceID: "model", in: MessageOptionsTransition)
                )
        }
        #endif
    }
    
    
    func sendMessage(){
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating{
            placeHolder = ChatPlaceHolders.returnRandomString()
            placeHolderVerb = ChatPlaceHolders.returnRandomVerb()
            if (inputMessage != ""){
                // Dismiss software keyboard while keeping hardware keyboard functional
                #if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if vibrateOnTokensReceived {
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.success)
                }
                #endif
                let input = inputMessage
                inputMessage = ""
                DispatchQueue.main.async {
                    // force render refresh to prevent a bug where the placeholder text isn't showing up and the blinking cursor disappears
                }
                
                // Use ChatCache to send message and handle generation
                chatCache.sendMessage(
                    modelName: selectedModel,
                    agent: selectedAgent,
                    inputText: input,
                    to: conversationID,
                    apiKey: apiKey,
                    withHapticFeedback: vibrateOnTokensReceived
                )
            }
        }
    }
    
    func sendMessageAsSystem(){
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating{
            placeHolder = ChatPlaceHolders.returnRandomString()
            placeHolderVerb = ChatPlaceHolders.returnRandomVerb()
            if (inputMessage != ""){
                // Dismiss software keyboard while keeping hardware keyboard functional
                #if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if vibrateOnTokensReceived {
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.warning)
                }
                #endif
                let input = inputMessage
                inputMessage = ""
                DispatchQueue.main.async {
                }
                
                chatCache.sendMessageAsSystem(inputText: input, to: conversationID)
            }
        }
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

class ChatPlaceHolders{
    static let placeHolders = [
        "Ask anything",
        "Type to chat",
        "Message the model",
        "Feel free to ask",
        "How can I help",
        "Thinking of something?",
        "Don't overthink it",
        "What's on your mind?",
        "Ready when you are",
        "What's up?",
        "Don't doom-scroll, talk to me",
        "Stuck? I could help",
        "If thou dost require aid… then speak plainly",
        "The next free AI is reserved for you",
        "Can I have message? UwU",
        "I don't bite, usually…",
        "Your move, genius",
        "Don't worry, I've seen worse",
        "Speak, mortal!",
        "Don't bore me, little worm",
        "Try me…",
        "Don't ask about r's in strawberry, please…",
        "Just an AI, don't fall in love…",
        "You sound great out of context",
        "Lay it on me",
        "We do what we must because we can",
        "Hey you, finally awake?",
        "Anyone can cook",
        "Ready, set, go",
    ]
    
    static let verbs = [
        "Message",
        "Talk to",
        "Work with",
        "Slack off with",
        "Chat with",
        "Huddle with",
        "Debate with",
        "Joke with",
        "Chill with",
        "Hang out with",
        "Entertain",
        "Employ",
        "Underpay",
        "Play with",
        "Rant to",
        "Plan with",
        "Overthink with",
        "Cook with",
        "Learn with",
        "Debug with",
        "Scare off",
        "Trust",
        "Join",
        "Butter up",
        "Count to 3 with",
        "Throw Ignifer with",
        "Test",
        "Explore with",
        "Hallucinate with",
        "Procrastinate with",
        "Procreate with",
        "Transform with",
        "Marvel at",
        "Survive with",
        "Report to",
        "Exercise with"
    ]
    
    public static func returnRandomString() -> String {
        return placeHolders.randomElement()!
    }
    
    public static func returnRandomVerb() -> String {
        return verbs.randomElement()!
    }
}

#Preview {
    //PromptField(conversation: .constant(Conversation(from: <#any Decoder#>)), inputMessage: .constant(""))
}
