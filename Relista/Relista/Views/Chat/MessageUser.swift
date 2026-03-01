//
//  MessageUser.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
#if os(iOS)
import QuickLook
#endif

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
                    if !message.attachmentLinks.isEmpty {
                        AttachmentThumbnailStrip(message: message)
                    }
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

// MARK: - Attachment thumbnails

private struct AttachmentThumbnailStrip: View {
    let message: Message
    @State private var quickLookURL: URL? = nil
    @State private var showQuickLook: Bool = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack() {
                    ForEach(message.attachmentLinks, id: \.self) { filename in
                        let url = AttachmentManager.imageURL(filename: filename, for: message.conversationID)
                        AttachmentThumb(url: url)
                            .frame(width: 128, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .padding(.horizontal, 4)
                            .onTapGesture {
                                //#if os(macOS)
                                //NSWorkspace.shared.open(url)
                                //#else
                                quickLookURL = url
                                showQuickLook = true
                                //#endif
                            }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)
                .frame(minWidth: geo.size.width, alignment: .trailing)
            }
        }
        .frame(height: 136)
        #if os(iOS)
        .sheet(isPresented: $showQuickLook) {
            if let url = quickLookURL {
                QuickLookPreview(url: url)
                    .ignoresSafeArea()
            }
        }
        #endif
    }
}

private struct AttachmentThumb: View {
    let url: URL
    @State private var image: Image? = nil

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .task {
            image = await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) async -> Image? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            #if os(iOS)
            guard let ui = UIImage(data: data) else { return nil }
            return Image(uiImage: ui)
            #elseif os(macOS)
            guard let ns = NSImage(data: data) else { return nil }
            return Image(nsImage: ns)
            #endif
        }.value
    }
}

// MARK: - Quick Look (iOS)

#if os(iOS)
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
#endif

// MARK: - Height measurement

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    //MessageUser(messageText: "Assistant message", availableWidth: 200)
}
