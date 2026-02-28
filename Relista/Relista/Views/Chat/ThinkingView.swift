//
//  ThinkingView.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ThinkingView: View {
    let thinkingBlock: ThinkingBlock

    @State private var isExpanded: Bool = false

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
            }
            .opacity(0.8)
            .animation(.default, value: thinkingBlock.isLoading)
            .onTapGesture {
                isExpanded.toggle()
            }
            .popover(isPresented: $isExpanded) {
                ScrollView {
                    Text(thinkingBlock.text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(width: 320, height: 400)
            }
            .presentationCompactAdaptation(.popover)
        }
        .padding(.vertical, 8)
    }
}
