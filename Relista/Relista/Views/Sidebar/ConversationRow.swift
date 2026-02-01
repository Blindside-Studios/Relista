//
//  ConversationRow.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        HStack {
            Text(conversation.title)
                .lineLimit(1)
                .minimumScaleFactor(1)
            Spacer()
        }
        .padding(10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .transition(
                        hSizeClass == .compact
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                    )
            }
        }
        .animation(.default, value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button {
                ChatCache.shared.setArchiveStatus(id: conversation.id, to: !conversation.isArchived)
            } label: {
                Label(conversation.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
