//
//  AgentRow.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct AgentRow: View {
    let agent: Agent
    let isSelected: Bool
    let isCurrentEmpty: Bool
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        HStack {
            Text(agent.icon + " " + agent.name)
                .lineLimit(1)
                .minimumScaleFactor(1)
            Spacer()
        }
        .padding(10)
        .background {
            if isCurrentEmpty && isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .transition(
                        hSizeClass == .compact
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                    )
            }
        }
        .animation(.default, value: isCurrentEmpty)
        .animation(.default, value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
