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
            Label("Tools", systemImage: anyEnabled ? "hammer.fill" : "hammer")
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.default, value: anyEnabled)
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
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 6)
        .onChange(of: isEnabled) { _, newValue in
            ToolRegistry.setEnabled(newValue, for: tool)
        }
    }
}

#Preview {
    ToolsButton()
}
