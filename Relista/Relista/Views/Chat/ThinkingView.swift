//
//  ThinkingView.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ThinkingView: View {
    let thinkingBlock: ThinkingBlock

    @Namespace private var ThinkingTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showPopover: Bool = false
    @State private var showSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Reasoning")
                    .fontWeight(.medium)
                if thinkingBlock.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .opacity(0.7)
            .animation(.default, value: thinkingBlock.isLoading)
            .animation(.default, value: showPopover)
            .animation(.default, value: showSheet)
            .matchedTransitionSource(id: "thinking", in: ThinkingTransition)
            .onTapGesture {
                if horizontalSizeClass == .compact { showSheet = true }
                else { showPopover.toggle() }
            }
            .popover(isPresented: $showPopover) {
                ThinkingContent(thinkingBlock: thinkingBlock)
                    .frame(width: 320)
                    .presentationCompactAdaptation(.popover)
            }
            #if os(iOS)
            .sheet(isPresented: $showSheet) {
                ScrollView(.vertical){
                    HStack{
                        //it won't move, I don't know why
                        Text("Chain of Thought")
                            .font(.title)
                            .offset(x: 4, y: 4)
                        Spacer()
                    }
                    .padding(4)
                    ThinkingContent(thinkingBlock: thinkingBlock)
                        .padding(4)
                }
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "thinking", in: ThinkingTransition))
            }
            #endif
        }
        .padding(.vertical, 8)
    }
}

private struct ThinkingContent: View {
    let thinkingBlock: ThinkingBlock

    var body: some View {
        ScrollView {
            Text(thinkingBlock.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
