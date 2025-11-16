//
//  ChatSplitView.swift
//  Relista
//
//  Created by Nicolas Helbig on 15.11.25.
//

import SwiftUI

// MARK: Unified Control

struct UnifiedSplitView<Sidebar: View, Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @State private var isSidebarOpen: Bool = false
    
    let sidebar: Sidebar
    let content: Content
    
    init(@ViewBuilder sidebar: () -> Sidebar,
         @ViewBuilder content: () -> Content) {
        self.sidebar = sidebar()
        self.content = content()
    }
    
    var body: some View {
        NavigationStack{ // so the toolbar displays
            #if os(iOS)
            if hSizeClass == .compact {
                ChatSplitView(isOpen: $isSidebarOpen) {
                    sidebar
                } content: {
                    content
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    withAnimation(.spring) {
                                        isSidebarOpen.toggle()
                                    }
                                } label: {
                                    Image(systemName: "sidebar.left")
                                }
                            }
                        }
                        .navigationTitle("")
                }
                
            } else {
                
                NavigationSplitView {
                    sidebar
                } detail: {
                    content
                }
            }
            #else
            NavigationSplitView {
                sidebar
            } detail: {
                content
            }
            #endif
        }
        .onAppear(){
            if hSizeClass == .compact {
                   isSidebarOpen = false
            } else {
                isSidebarOpen = true
            }
        }
    }
}

// MARK: Split View Control

struct ChatSplitView<Sidebar: View, Content: View>: View {
    let sidebar: Sidebar
    let content: Content
    
    @Binding var isOpen: Bool
    @State private var dragOffset: CGFloat = 0
    
    #if os(iOS)
    private func sidebarSnapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
    #endif
    
    init(isOpen: Binding<Bool>,
         @ViewBuilder sidebar: () -> Sidebar,
         @ViewBuilder content: () -> Content) {
        self._isOpen = isOpen
        self.sidebar = sidebar()
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let drawerWidth = width * 0.75
            let baseOffset: CGFloat = isOpen ? drawerWidth : 0
            let currentOffset = min(max(baseOffset + dragOffset, 0), drawerWidth)
            
            ZStack(alignment: .leading) {
                
                // MAIN CONTENT
                content
                    .contentShape(Rectangle())
                    .opacity(1.0 - ((currentOffset / drawerWidth) * 0.25))
                    .background(Color.gray.opacity((currentOffset / drawerWidth) * 0.25))
                    .offset(x: currentOffset)
                    .overlay{
                        if currentOffset > 0 {
                            Color.clear
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring) {
                                        isOpen = false
                                    }
                                }
                        }
                    }
                                    
                // SIDEBAR
                sidebar
                    .frame(width: drawerWidth)
                    .offset(x: currentOffset - drawerWidth)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        let t = value.translation
                        guard abs(t.width) > abs(t.height) else {
                            dragOffset = 0
                            return
                        }
                        dragOffset = t.width
                    }
                    .onEnded { value in
                        let t = value.translation
                        guard abs(t.width) > abs(t.height) else {
                            dragOffset = 0
                            return
                        }
                        let base = isOpen ? drawerWidth : 0
                        let predicted = base + value.predictedEndTranslation.width
                        let willOpen = predicted > drawerWidth / 2
                        withAnimation(.spring(response: 0.3)) {
                            #if os(iOS)
                            if willOpen != isOpen {
                                sidebarSnapHaptic()
                            }
                            #endif
                            isOpen = willOpen
                            dragOffset = 0
                        }
                    }
            )
        }
    }
}

#Preview {
    //ChatSplitView()
}
