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

    @Namespace private var ToolUseTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showPopover: Bool = false
    @State private var showSheet: Bool = false

    private var isWebSearch: Bool { toolBlock.toolName == "web_search" }

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
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(0.7)
            .animation(.default, value: toolBlock.isLoading)
            .animation(.default, value: showPopover)
            .animation(.default, value: showSheet)
            .matchedTransitionSource(id: toolBlock.id, in: ToolUseTransition)
            .onTapGesture {
                if horizontalSizeClass == .compact && isWebSearch { showSheet = true }
                else { showPopover.toggle() }
            }
            .popover(isPresented: $showPopover) {
                ToolUseContent(toolBlock: toolBlock)
                    .frame(width: 300)
                    .presentationCompactAdaptation(.popover)
            }
            #if os(iOS)
            .sheet(isPresented: $showSheet) {
                ScrollView(.vertical){
                    HStack{
                        //it won't move, I don't know why
                        Text(toolBlock.displayName)
                            .font(.title)
                            .offset(x: 4, y: 4)
                        Spacer()
                    }
                    .padding(4)
                    ToolUseContent(toolBlock: toolBlock)
                        .padding(4)
                }
                .navigationTransition(.zoom(sourceID: toolBlock.id, in: ToolUseTransition))
                .presentationDetents([.medium, .large])
            }
            #endif
        }
        .padding(.vertical, 8)
    }
}

private struct ToolUseContent: View {
    let toolBlock: ToolUseBlock

    var body: some View {
        ScrollView {
            StructuredText(markdown: toolBlock.result ?? "Waiting for results…")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
