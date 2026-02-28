//
//  InputUI.swift
//  Relista
//
//  Created by Nicolas Helbig on 06.01.26.
//

import SwiftUI

struct InputUI: View {
    // pass-through
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @Binding var primaryAccentColor: Color
    @Binding var secondaryAccentColor: Color
    
    // own logic
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isChatBlank: Bool{
        ChatCache.shared.loadedChats[conversationID]?.messages.isEmpty ?? false
    }
    private var agentIcon: String{
        if selectedAgent != nil{
            AgentManager.getUIAgentImage(fromUUID: selectedAgent!)
        } else {
            "🐙"
        }
    }
    @State private var greetingBannerText: String = ""
    @State private var displayedGreeting: String = ""
    @State private var greetingTask: Task<Void, Never>?
    
    var body: some View {
        Group{
            if horizontalSizeClass == .compact {
                VStack (alignment: .center){
                    VStack{
                        if isChatBlank{
                            Spacer()
                            Text(agentIcon)
                                .font(.system(size: 72))
                            Text(displayedGreeting)
                                .opacity(0.75)
                                .multilineTextAlignment(.center)
                                .font(.largeTitle)
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                    }
                    .padding()
                    .transition(
                        AnyTransition.blurFade.combined(with: .offset(y: -150)).combined(with: .opacity)
                    )
                    
                    if isChatBlank {
                        NewChatAgentPicker(conversationID: $conversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                            .transition(
                                AnyTransition.blurFade.combined(with: .offset(y: 50)).combined(with: .opacity)
                            )
                    }
                    
                    PromptField(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor)
                }
            } else {
                VStack{
                    if isChatBlank {
                        Spacer()

                        HStack(alignment: .bottom){
                            Spacer()
                            Text(agentIcon)
                            Text(displayedGreeting)
                                .opacity(0.85)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding()
                        .font(Font.largeTitle.bold())
                        .frame(height: 20, alignment: .bottom)
                        .transition(
                            AnyTransition.blurFade.combined(with: .offset(y: -150)).combined(with: .opacity)
                        )
                    }
                    PromptField(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor)
                    if isChatBlank {
                        NewChatAgentPicker(conversationID: $conversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                            .transition(
                                AnyTransition.blurFade.combined(with: .offset(y: 350)).combined(with: .opacity)
                            )
                        // double spacer so the actual content is above center
                        Spacer()
                        Spacer()
                    }
                }
                // center-alignment
                .frame(maxWidth: .infinity)
                .frame(maxWidth: 750)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isChatBlank ? 50 : 0)
            }
        }
        .task(id: conversationID){
            greetingTask?.cancel()
            if !isChatBlank { return } // don't create a greeting when the user navigates to an actual chat
            
            displayedGreeting = ""
            
            do {
                greetingBannerText = try await Mistral(apiKey: KeychainHelper.shared.mistralAPIKey)
                    .generateGreetingBanner(agent: selectedAgent)
                
                greetingTask = Task {
                    await animateGreeting(greetingBannerText)
                }
            } catch {
                greetingBannerText = "Hello!"
                displayedGreeting = "Hello!"
            }
        }
        .animation(.bouncy, value: isChatBlank)
    }
    
    private func animateGreeting(_ fullText: String) async {
        displayedGreeting = ""
        
        for character in fullText {
            if Task.isCancelled { return }
            
            displayedGreeting.append(character)
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 30),
            identity: BlurModifier(radius: 0)
        )
    }
}

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

#Preview {
    //InputUI()
}
