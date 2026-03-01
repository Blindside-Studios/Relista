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

/// The + button in the CommandBar. Opens a menu to attach photos or take a picture.
struct AttachmentPickerButton: View {
    @Binding var pendingAttachments: [PendingAttachment]

    #if os(iOS)
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    #endif

    var body: some View {
        Menu {
            Button("Upload File", systemImage: "folder") {
                // Not yet implemented
            }
            .disabled(true)

            #if os(iOS)
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Upload Photo", systemImage: "photo.on.rectangle")
            }

            Button("Take Photo", systemImage: "camera") {
                showCamera = true
            }
            #else
            Button("Choose Image…", systemImage: "photo") {
                openImagePanel()
            }
            #endif
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // Normalize to JPEG so we have a consistent format and known extension
                    let normalized = UIImage(data: data).flatMap { $0.jpegData(compressionQuality: 0.9) } ?? data
                    await MainActor.run {
                        pendingAttachments.append(PendingAttachment(data: normalized, fileExtension: "jpg"))
                        photoPickerItem = nil
                    }
                }
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

    #if os(macOS)
    private func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.jpeg, UTType.png, UTType.gif, UTType.webP, UTType.heic
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let data = try? Data(contentsOf: url) {
                let ext = url.pathExtension.lowercased().isEmpty ? "jpg" : url.pathExtension.lowercased()
                pendingAttachments.append(PendingAttachment(data: data, fileExtension: ext))
            }
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
