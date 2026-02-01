//
//  ChatFilterMenu.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct ChatFilterMenu: View {
    @Binding var chatFilter: ChatFilter
    @ObservedObject var agentManager: AgentManager

    var body: some View {
        Menu {
            Section("Show") {
                ForEach(ChatKind.allCases, id: \.self) { kind in
                    Button {
                        chatFilter = .kind(kind)
                    } label: {
                        if case .kind(kind) = chatFilter {
                            Label(kind.rawValue, systemImage: "checkmark")
                        } else {
                            Text(kind.rawValue)
                        }
                    }
                }
            }

            if !agentManager.customAgents.isEmpty {
                Section("By Squidlet") {
                    ForEach(agentManager.customAgents) { agent in
                        Button {
                            chatFilter = .agent(agent.id)
                        } label: {
                            if case .agent(agent.id) = chatFilter {
                                Label(agent.icon + " " + agent.name, systemImage: "checkmark")
                            } else {
                                Text(agent.icon + " " + agent.name)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(filterLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                Image(systemName: "chevron.up.chevron.down")
            }
            .opacity(0.7)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .labelStyle(.titleAndIcon)
    }

    private var filterLabel: String {
        switch chatFilter {
        case .kind(let kind):
            return kind.rawValue
        case .agent(let agentID):
            if let agent = agentManager.customAgents.first(where: { $0.id == agentID }) {
                return agent.icon + " " + agent.name
            }
            return "Unknown Agent"
        }
    }
}

enum ChatKind: String, CaseIterable, Codable {
    case recents = "Recents"
    case archived = "Archived"
    case hideChats = "Hide Chats"
}

enum ChatFilter: Hashable {
    case kind(ChatKind)
    case agent(UUID)
}
