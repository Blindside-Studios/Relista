//
//  SearchButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 04.12.25.
//

import SwiftUI

struct SearchButton: View {
    @Binding var useSearch: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Button{
            useSearch.toggle()
        } label: {
            Label {
                Group {
                    if useSearch {
                        Text(horizontalSizeClass != .compact ? "Search" : "Web")
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
                Image(systemName: useSearch ? "globe.fill" : "globe")
                    .foregroundStyle(useSearch ? .blue : .primary)
                    #if os(macOS)
                    .font(.system(size: 15, weight: .semibold))
                    #endif
            }
            .background {
                GeometryReader { backgroundFrame in
                    RoundedRectangle(cornerRadius: backgroundFrame.size.height + 2, style: .continuous) // +2 to account for padding
                        .fill(Color.blue.opacity(useSearch ? 0.15 : 0.0001))
                        .padding(useSearch ? -3 : 4)
                }
            }
            // the following two lines to eliminate the gap to the right because the system thinks a label text is being displayed
            .padding(.horizontal, !useSearch ? -4 : 0)
            .offset(x: !useSearch ? 4 : 0)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useSearch)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    SearchButton(useSearch: .constant(false))
}
