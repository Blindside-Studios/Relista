//
//  ToolUseView.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ToolUseView: View {
    let toolBlock: ToolUseBlock

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: toolBlock.icon)
                    .imageScale(.small)
                Text(toolBlock.displayName)
                    .fontWeight(.medium)
                Text("\(toolBlock.inputSummary)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if toolBlock.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.small)
                }
            }
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            if !toolBlock.isLoading, let result = toolBlock.result {
                Divider()
                    .padding(.horizontal, 10)
                DisclosureGroup(isExpanded: $isExpanded) {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                } label: {
                    Text(isExpanded ? "Hide results" : "Show results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.vertical, 2)
    }
}
