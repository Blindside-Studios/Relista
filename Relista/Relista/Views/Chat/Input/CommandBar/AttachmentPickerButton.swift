//
//  AttachmentPickerButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import SwiftUI
import PhotosUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

/// A shared struct representing an image staged for attachment before the message is sent.
struct PendingAttachment: Identifiable {
    let id: UUID = UUID()
    let data: Data
    let fileExtension: String
}

/// The + button in the CommandBar. Opens a menu to attach photos or files.
struct AttachmentPickerButton: View {
    @Binding var pendingAttachments: [PendingAttachment]

    // Shared across platforms
    @State private var showPhotoPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []

    #if os(iOS)
    @State private var showFilePicker = false
    @State private var showCamera = false
    #endif

    var body: some View {
        Menu {
            // Photos app picker — works on iOS and macOS via .photosPicker modifier below.
            Button("Select Photo", systemImage: "photo.on.rectangle") {
                showPhotoPicker = true
            }

            #if os(iOS)
            // Image-only file picker (Files app, cloud storage, etc.)
            Button("Choose File", systemImage: "folder") {
                showFilePicker = true
            }

            Button("Take Photo", systemImage: "camera") {
                showCamera = true
            }

            if UIPasteboard.general.hasImages {
                Button("Paste Image", systemImage: "doc.on.clipboard") {
                    pasteFromClipboard()
                }
            }
            #else
            // On macOS, NSOpenPanel covers the file-browser use-case.
            Button("Choose File", systemImage: "folder") {
                openImagePanel()
            }
            #endif
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        // Presented as a modifier so the sheet has a stable host in the view hierarchy.
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $photoPickerItems,
                      maxSelectionCount: nil,
                      matching: .images)
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            let captured = items
            photoPickerItems = []           // clear immediately so re-opening works
            for item in captured {
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    guard let attachment = normalize(data) else { return }
                    await MainActor.run {
                        pendingAttachments.append(attachment)
                    }
                }
            }
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url),
                      let attachment = normalize(data) else { continue }
                pendingAttachments.append(attachment)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { data, ext in
                pendingAttachments.append(PendingAttachment(data: data, fileExtension: ext))
            }
            .ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Helpers

    /// Decodes any OS-supported image format and re-encodes to JPEG.
    private func normalize(_ data: Data) -> PendingAttachment? {
        #if os(iOS)
        guard let ui = UIImage(data: data),
              let jpeg = ui.jpegData(compressionQuality: 0.9) else { return nil }
        return PendingAttachment(data: jpeg, fileExtension: "jpg")
        #else
        guard let ns = NSImage(data: data),
              let tiff = ns.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        else { return nil }
        return PendingAttachment(data: jpeg, fileExtension: "jpg")
        #endif
    }

    #if os(iOS)
    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 0.9) else { return }
        pendingAttachments.append(PendingAttachment(data: data, fileExtension: "jpg"))
    }
    #endif

    #if os(macOS)
    private func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.jpeg, UTType.png, UTType.gif, UTType.webP,
            UTType.heic, UTType.tiff, UTType.image,
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let ns = NSImage(contentsOf: url),
                  let attachment = normalize(ns.tiffRepresentation ?? Data()) else { continue }
            pendingAttachments.append(attachment)
        }
    }
    #endif
}

// MARK: - Camera capture (iOS only)

#if os(iOS)
private struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (Data, String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (Data, String) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (Data, String) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                onCapture(data, "jpg")
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif
