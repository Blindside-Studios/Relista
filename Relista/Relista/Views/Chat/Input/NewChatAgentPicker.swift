//
//  NewChatAgentPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 18.01.26.
//

import SwiftUI

struct NewChatAgentPicker: View {
    @Binding var conversationID: UUID
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    
    @ObservedObject private var agentManager = AgentManager.shared
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                HStack {
                    Text("🐙 Default")
                    Spacer()
                        .frame(width: 2)
                }
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue.opacity(selectedAgent == nil ? 0.5 : 0))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.default, value: selectedAgent)
                .contentShape(Rectangle())
                .onTapGesture {
                    conversationID = ConversationManager.createNewConversation(
                        fromID: conversationID
                    ).newChatUUID
                    selectedAgent = nil
                }
                
                
                ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                    let isCurrentAgent = selectedAgent == Optional(agent.id)
                    let colorResponse = AgentManager.getUIAgentColors(fromUUID: agent.id)
                    let primaryAccentColor: Color = {
                        if let primaryHex = colorResponse[0] {
                            let cleanPrimary = primaryHex.replacingOccurrences(of: "#", with: "")
                            return Color(hex: cleanPrimary) ?? .blue
                        }
                        return .blue
                    }()
                    
                    HStack {
                        Text(agent.icon + " " + agent.name)
                        Spacer()
                            .frame(width: 2)
                    }
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThickMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(primaryAccentColor.opacity(isCurrentAgent ? 0.5 : 0))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .animation(.default, value: isCurrentAgent)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let result = ConversationManager.createNewConversation(
                            fromID: conversationID,
                            withAgent: agent.id
                        )
                        conversationID = result.newChatUUID
                        selectedAgent = agent.id
                        if !agent.model.isEmpty { selectedModel = agent.model }
                    }
                }
            }
            .font(.callout)
            .padding(.horizontal, 12)
        }
        //.scrollClipDisabled()
        .scrollIndicators(.hidden)
        .blocksHorizontalSidebarGesture()
    }
}

#Preview {
    //NewChatAgentPicker(selectedAgent: .constant(nil))
}
