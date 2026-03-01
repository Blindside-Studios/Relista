//
//  PendingImageStrip.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import SwiftUI

/// Horizontally scrolling row of image thumbnails shown above the text field
/// while the user is composing a message with attachments.
struct PendingImageStrip: View {
    @Binding var pendingAttachments: [PendingAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pendingAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        LocalThumbnail(data: attachment.data)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            withAnimation(.bouncy(duration: 0.25)) {
                                pendingAttachments.removeAll { $0.id == attachment.id }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 5, y: -5)
                    }
                }
            }
            //.padding(.horizontal, 4)
            .padding(.horizontal, 15)
            .padding(.top, 10)
        }
        .frame(height: 74)
        .padding(.top, -10)
        .padding(.horizontal, -15)
    }
}

// MARK: - Cross-platform in-memory thumbnail

/// Renders image data as a SwiftUI Image, loading off the main thread.
struct LocalThumbnail: View {
    let data: Data
    @State private var image: Image? = nil

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
                    .overlay(ProgressView().scaleEffect(0.6))
            }
        }
        .task {
            image = await loadImage(from: data)
        }
    }

    private func loadImage(from data: Data) async -> Image? {
        await Task.detached(priority: .userInitiated) {
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
