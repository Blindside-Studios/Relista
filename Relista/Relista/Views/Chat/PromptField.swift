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
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @FocusState private var isTextFieldFocused: Bool
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var chatCache = ChatCache.shared
    @State private var placeHolder = ChatPlaceHolders.returnRandomString()
    
    @Binding var useSearch: Bool
    @Binding var useReasoning: Bool
    
    @State private var isTryingToAddNewLine = false // workaround for .handled because iPadOS 26 is garbage

    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true

    var body: some View {
        #if os(macOS)
        let spacing: CGFloat = 12
        #else
        let spacing: CGFloat = 16
        #endif
        VStack(spacing: spacing) {
            TextField(placeHolder, text: $inputMessage, axis: .vertical)
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .onSubmit(sendMessage)
                .onKeyPress { keyPress in
                    if keyPress.modifiers == .shift
                        && keyPress.key == .return
                    {
                        #if os(iOS)
                        isTryingToAddNewLine = true
                        #endif
                        inputMessage += "\n"
                        return .handled
                    } else {
                        return .ignored
                    }
                }
                //.padding(spacing)
            CommandBar(useSearch: $useSearch, useReasoning: $useReasoning, selectedModel: $selectedModel, conversationID: $conversationID, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem, appendDummyMessages: appendDummyMessages)
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
        .onChange(of: selectedAgent, refreshPlaceHolder)
    }
    
    func sendMessage(){
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating && !isTryingToAddNewLine {
            placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
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
                    withHapticFeedback: vibrateOnTokensReceived,
                    useSearch: useSearch
                )
            }
        }
        else{
            #if os(iOS)
            DispatchQueue.main.async {
                isTextFieldFocused = true
                isTryingToAddNewLine = false
            }
            #endif
        }
    }
    
    func sendMessageAsSystem(){
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating{
            placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
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
    
    func refreshPlaceHolder(){
        placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
    }
}

class ChatPlaceHolders{
    public static func returnAppropriatePlaceholder(agentUUID: UUID?) -> String {
        if agentUUID == nil{
            return returnRandomString()
        }
        else{
            return "\(returnRandomVerb()) @\(AgentManager.getUIAgentName(fromUUID: agentUUID!))"
        }
    }
    
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
