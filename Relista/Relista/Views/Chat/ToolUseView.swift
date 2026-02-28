//
//  ToolUseView.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI
import Textual

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
                if toolBlock.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                }
            }
            .opacity(0.8)
            .animation(.default, value: toolBlock.isLoading)
            .onTapGesture {
                isExpanded.toggle()
            }
            .popover(isPresented: $isExpanded){
                StructuredText(markdown: toolBlock.result ?? "Waiting for results…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 300)
                    .padding()
            }
            .presentationCompactAdaptation(.popover)
        }
        .padding(.vertical, 8)
    }
}
