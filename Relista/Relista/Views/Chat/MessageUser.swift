//
//  MessageUser.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct MessageUser: View {
    let message: Message
    let availableWidth: CGFloat
    @State private var isExpanded: Bool = false
    @State private var naturalHeight: CGFloat = 0
    
    @Binding var primaryAccentColor: Color
    
    @AppStorage("ShowUserMessageToolbars") private var showUserMessageToolbars: Bool = false
    
    private var needsTruncation: Bool {
        naturalHeight > 200
    }
    
    var body: some View {
        VStack(spacing: 0){
            HStack(alignment: .top) {
                Spacer(minLength: availableWidth * 0.2)
                VStack(alignment: .leading, spacing: 4){
                    Text(message.text)
                        .frame(maxHeight: isExpanded ? .infinity : 200, alignment: .topLeading)
                        .foregroundStyle(message.role == .system ? Color.orange : Color.primary)
                        .clipped()
                        .padding()
                        .glassEffect(.regular.tint(primaryAccentColor.opacity(0.3)), in: .rect(cornerRadius: 25.0, style: .continuous))
                        .background(
                            Text(message.text)
                                .padding()
                                .foregroundStyle(.clear)
                                .fixedSize(horizontal: false, vertical: true)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                                    }
                                )
                        )
                        .onPreferenceChange(HeightPreferenceKey.self) { height in
                            naturalHeight = height
                        }
                        .onTapGesture(){
                            if needsTruncation{
                                withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                                    isExpanded.toggle()
                                }
                            }
                        }
                        .contextMenu{
                            Button {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                                #else
                                UIPasteboard.general.string = message.text
                                #endif
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    
                    if showUserMessageToolbars{
                        HStack(spacing: 8){
                            if needsTruncation {
                                Button{
                                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                                        isExpanded.toggle()
                                    }
                                } label: {
                                    HStack{
                                        Label("Expand/collapse full message", systemImage: "chevron.down")
                                            .rotationEffect(isExpanded ? Angle(degrees: -180) : Angle(degrees: 0))
                                        //.animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: isExpanded)
                                    }
                                }
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)
                                .labelStyle(.iconOnly)
                                .backgroundStyle(.clear)
                            }
                            
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
                        }
                        .opacity(0.5)
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    //MessageUser(messageText: "Assistant message", availableWidth: 200)
}
