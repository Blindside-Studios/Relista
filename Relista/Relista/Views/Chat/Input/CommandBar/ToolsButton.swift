//
//  ToolsButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ToolsButton: View {
    @State private var showPopover = false
    @State private var anyEnabled = !ToolRegistry.enabledTools().isEmpty

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Label {
                Group {
                    if anyEnabled {
                        Text("Tools")
                            .offset(x: -4)
                            .foregroundStyle(.purple)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    } else {
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            } icon: {
                Image(systemName: anyEnabled ? "hammer.fill" : "hammer")
                    .foregroundStyle(anyEnabled ? .purple : .primary)
                    #if os(macOS)
                    .font(.system(size: 15, weight: .semibold))
                    #endif
            }
            .background {
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: g.size.height + 2, style: .continuous)
                        .fill(Color.purple.opacity(anyEnabled ? 0.15 : 0.0001))
                        .padding(anyEnabled ? -3 : 4)
                }
            }
            .padding(.horizontal, !anyEnabled ? -4 : 0)
            .offset(x: !anyEnabled ? 4 : 0)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: anyEnabled)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .popover(isPresented: $showPopover) {
            ToolsPopover()
                .onDisappear {
                    anyEnabled = !ToolRegistry.enabledTools().isEmpty
                }
        }
    }
}

private struct ToolsPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tools")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(ToolRegistry.allTools.indices, id: \.self) { i in
                ToolToggleRow(tool: ToolRegistry.allTools[i])
                if i < ToolRegistry.allTools.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .presentationCompactAdaptation(.popover)
    }
}

private struct ToolToggleRow: View {
    let tool: any ChatTool
    @State private var isEnabled: Bool

    init(tool: any ChatTool) {
        self.tool = tool
        self._isEnabled = State(initialValue: ToolRegistry.isEnabled(tool))
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 10) {
                Image(systemName: tool.icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .fontWeight(.medium)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .onChange(of: isEnabled) { _, newValue in
            ToolRegistry.setEnabled(newValue, for: tool)
        }
    }
}

#Preview {
    ToolsButton()
}
