//
//  ReasoningButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct ReasoningButton: View {
    @Binding var useReasoning: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Button{
            useReasoning.toggle()
        } label: {
            Label {
                Group {
                    if useReasoning {
                        Text(horizontalSizeClass != .compact ? "Reasoning" : "Think")
                            .offset(x: -4)
                            .foregroundStyle(.blue)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity
                            ))
                    } else {
                        Color.clear
                            .frame(width: 0, height: 0)    // truly zero width
                    }
                }
            } icon: {
                Image(systemName: useReasoning ? "lightbulb.fill" : "lightbulb")
                    .foregroundStyle(useReasoning ? .blue : .primary)
                    #if os(iOS)
                    .font(.system(size: 15, weight: .medium))
                    #endif
            }
            .background {
                GeometryReader { backgroundFrame in
                    RoundedRectangle(cornerRadius: backgroundFrame.size.height + 2, style: .continuous) // +2 to account for padding
                        .fill(Color.blue.opacity(useReasoning ? 0.15 : 0.0001))
                        .padding(useReasoning ? -3 : 4)
                }
            }
            // the following two lines to eliminate the gap to the right because the system thinks a label text is being displayed
            .padding(.horizontal, !useReasoning ? -4 : 0)
            .offset(x: !useReasoning ? 4 : 0)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useReasoning)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    ReasoningButton(useReasoning: .constant(false))
}
