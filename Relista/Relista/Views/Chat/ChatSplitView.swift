//
//  ChatSplitView.swift
//  Relista
//
//  Created by Nicolas Helbig on 15.11.25.
//

import SwiftUI
import Combine

// MARK: Environment Key for Sidebar Selection

private struct SidebarSelectionActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var onSidebarSelection: (() -> Void)? {
        get { self[SidebarSelectionActionKey.self] }
        set { self[SidebarSelectionActionKey.self] = newValue }
    }
}

// MARK: Sidebar Gesture Coordination

@MainActor
class SidebarGestureCoordinator: ObservableObject {
    @Published var isBlocked: Bool = false
}

private struct SidebarGestureCoordinatorKey: EnvironmentKey {
    static let defaultValue: SidebarGestureCoordinator? = nil
}

extension EnvironmentValues {
    var sidebarGestureCoordinator: SidebarGestureCoordinator? {
        get { self[SidebarGestureCoordinatorKey.self] }
        set { self[SidebarGestureCoordinatorKey.self] = newValue }
    }
}

extension View {
    /// Blocks the sidebar swipe gesture while this view is being scrolled horizontally
    func blocksHorizontalSidebarGesture() -> some View {
        self.modifier(HorizontalScrollBlocker())
    }

    /// Manually block/unblock the sidebar gesture (useful for text selection)
    func blocksSidebarGesture(_ blocked: Bool) -> some View {
        self.modifier(ManualSidebarBlocker(blocked: blocked))
    }
}

private struct HorizontalScrollBlocker: ViewModifier {
    @Environment(\.sidebarGestureCoordinator) private var coordinator
    @GestureState private var isDragging: Bool = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
            )
            .onChange(of: isDragging) { _, newValue in
                coordinator?.isBlocked = newValue
            }
    }
}

private struct ManualSidebarBlocker: ViewModifier {
    @Environment(\.sidebarGestureCoordinator) private var coordinator
    let blocked: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: blocked, initial: true) { _, newValue in
                coordinator?.isBlocked = newValue
            }
            .onDisappear {
                coordinator?.isBlocked = false
            }
    }
}

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
                        .environment(\.onSidebarSelection, {
                            withAnimation(.spring) {
                                isSidebarOpen = false
                            }
                        })
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
    @State private var isGestureActive: Bool = false
    @StateObject private var gestureCoordinator = SidebarGestureCoordinator()

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
                    .environment(\.sidebarGestureCoordinator, gestureCoordinator)
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
                        // Don't activate if content is handling a gesture
                        if gestureCoordinator.isBlocked {
                            dragOffset = 0
                            isGestureActive = false
                            return
                        }

                        // On first change, check if it's a horizontal gesture
                        if !isGestureActive {
                            let t = value.translation
                            guard abs(t.width) > abs(t.height) else { return }
                            isGestureActive = true
                        }

                        guard isGestureActive else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard isGestureActive else {
                            dragOffset = 0
                            isGestureActive = false
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
                        isGestureActive = false
                    }
            )
            .onChange(of: isOpen) { oldValue, newValue in
                // Dismiss keyboard when opening sidebar
                if newValue == true && oldValue == false {
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
        }
    }
}

#Preview {
    //ChatSplitView()
}
