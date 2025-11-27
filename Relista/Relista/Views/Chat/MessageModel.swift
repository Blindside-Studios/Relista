//
//  MessageModel.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import MarkdownUI

struct MessageModel: View {
    let message: Message
    
    @AppStorage("AlwaysShowFullModelMessageToolbar") private var toolbarExpansionPreference: Bool = false
    @State private var isToolbarExpanded: Bool = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack{
            HStack {
                Markdown(message.text)
                    .textSelection(.enabled)
                    .padding()
                
                Spacer()
            }
            HStack(spacing: 8) {
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.text, forType: .string)
                    #else
                    UIPasteboard.general.string = message.text
                    #endif
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .contentShape(Rectangle())
                        .scaleEffect(0.8)
                }
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                
                Button {
                    // regrenerate
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .contentShape(Rectangle())
                        .scaleEffect(0.8)
                }
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                
                if (isToolbarExpanded){
                    Divider()
                        .frame(height:12)
                    Text(formatMessageTimestamp(message.timeStamp))
                    Divider()
                        .frame(height:12)
                    Text(message.modelUsed)
                }
                
                Button {
                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                        isToolbarExpanded.toggle()
                    }
                } label: {
                    Label("Expand/Collapse toolbar", systemImage: "chevron.forward")
                        .contentShape(Rectangle())
                        .scaleEffect(0.8)
                        .rotationEffect(isToolbarExpanded ? Angle(degrees: -180) : Angle(degrees: 0))
                }
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                
                Spacer()
            }
            .padding(.leading, 15)
            .opacity(0.5)
            .padding(.top, -10)
            
            Spacer()
                .frame(minHeight: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSizeClass == .compact ? 0 : 8)
        .onAppear(){
            if toolbarExpansionPreference {isToolbarExpanded = true}
        }
    }
    
    func formatMessageTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    //MessageModel(messageText: "User message")
}
