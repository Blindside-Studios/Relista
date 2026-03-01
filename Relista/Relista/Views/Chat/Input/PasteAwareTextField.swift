//
//  PasteAwareTextField.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import SwiftUI

// MARK: - iOS -----------------------------------------------------------------

#if os(iOS)
import UIKit

/// A growing, multi-line text view that intercepts image paste **before** UIKit
/// can convert clipboard contents to a filename or URL string.  Replaces the
/// SwiftUI `TextField` in the chat input bar on iOS/iPadOS.
struct PasteAwareTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onImagePaste: (PendingAttachment) -> Void

    /// Set to `true` to request first-responder focus; automatically reset to
    /// `false` after the view responds (edge-triggered).
    @Binding var focusRequest: Bool

    func makeUIView(context: Context) -> PasteInterceptingTextView {
        let tv = PasteInterceptingTextView()
        tv.delegate = context.coordinator
        tv.onImagePaste = onImagePaste
        tv.onSubmit = onSubmit
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false          // grows with content; SwiftUI handles layout
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Show placeholder on first render
        tv.text = placeholder
        tv.textColor = UIColor.placeholderText
        tv.isShowingPlaceholder = true
        return tv
    }

    func updateUIView(_ tv: PasteInterceptingTextView, context: Context) {
        // Sync an externally changed binding into the view (e.g. cleared after send),
        // but never overwrite the placeholder text — that's the correct idle state.
        if !tv.isShowingPlaceholder, tv.text != text {
            tv.text = text
            tv.invalidateIntrinsicContentSize()
        }
        // If binding was cleared while the view is not focused, show placeholder.
        if text.isEmpty, !tv.isFirstResponder, !tv.isShowingPlaceholder {
            tv.text = placeholder
            tv.textColor = UIColor.placeholderText
            tv.isShowingPlaceholder = true
            tv.invalidateIntrinsicContentSize()
        }
        // Honour one-shot focus request.
        if focusRequest {
            tv.becomeFirstResponder()
            DispatchQueue.main.async { focusRequest = false }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PasteInterceptingTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let lineHeight = uiView.font?.lineHeight ?? 20
        let maxHeight = ceil(lineHeight * 10)

        // Ask the text view how tall it wants to be at the proposed width.
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(fitting.height, maxHeight)

        // Enable internal scrolling only when content overflows the cap.
        let needsScroll = fitting.height > maxHeight
        if uiView.isScrollEnabled != needsScroll {
            uiView.isScrollEnabled = needsScroll
        }

        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PasteAwareTextField

        init(parent: PasteAwareTextField) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard let tv = textView as? PasteInterceptingTextView,
                  tv.isShowingPlaceholder else { return }
            tv.text = ""
            tv.textColor = UIColor.label
            tv.isShowingPlaceholder = false
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard let tv = textView as? PasteInterceptingTextView else { return }
            if tv.text.isEmpty {
                tv.text = parent.placeholder
                tv.textColor = UIColor.placeholderText
                tv.isShowingPlaceholder = true
                tv.invalidateIntrinsicContentSize()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let tv = textView as? PasteInterceptingTextView,
                  !tv.isShowingPlaceholder else { return }
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }

        /// Intercepts the soft keyboard's Return key and submits instead of
        /// inserting a newline.  Hardware Return is handled by UIKeyCommand.
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }
}

// MARK: UITextView subclass

/// UITextView subclass that adds image-priority paste and hardware-keyboard
/// submit / newline commands.
final class PasteInterceptingTextView: UITextView {
    var onImagePaste: ((PendingAttachment) -> Void)?
    var onSubmit: (() -> Void)?
    var isShowingPlaceholder: Bool = false

    // MARK: Hardware keyboard commands

    override var keyCommands: [UIKeyCommand]? {
        var cmds = super.keyCommands ?? []
        // Bare Return → submit (takes priority over default newline insertion)
        cmds.append(UIKeyCommand(
            title: "Send",
            action: #selector(handleSubmit),
            input: "\r",
            modifierFlags: []
        ))
        // Shift+Return → newline (preserves expected composition behaviour)
        cmds.append(UIKeyCommand(
            title: "New Line",
            action: #selector(handleNewline),
            input: "\r",
            modifierFlags: .shift
        ))
        return cmds
    }

    @objc private func handleSubmit() { onSubmit?() }
    @objc private func handleNewline() { insertText("\n") }

    // MARK: Paste interception

    override func paste(_ sender: Any?) {
        let pb = UIPasteboard.general
        if let image = pb.image,
           let jpeg = image.jpegData(compressionQuality: 0.9) {
            // Image wins — never fall through to the default text paste that
            // would insert a filename or URL string.
            onImagePaste?(PendingAttachment(data: jpeg, fileExtension: "jpg"))
        } else {
            super.paste(sender)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

#endif // os(iOS)

// MARK: - macOS ---------------------------------------------------------------

#if os(macOS)
import AppKit

/// Observes local key-down events so Cmd+V is intercepted **before** NSTextField
/// can paste a filename or address as plain text.
///
/// When the pasteboard contains image data (pixel bytes or a Finder-copied image
/// file) the image is captured and the event is consumed; for everything else the
/// event passes through unchanged so normal text paste still works.
final class MacOSPasteMonitor {
    private var eventMonitor: Any?

    func start(onImagePaste: @escaping (PendingAttachment) -> Void) {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only intercept plain Cmd+V (no other modifiers).
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "v" else {
                return event
            }
            if let attachment = self?.imageFromPasteboard() {
                DispatchQueue.main.async { onImagePaste(attachment) }
                return nil      // consume — NSTextField never sees this event
            }
            return event        // no image; let normal text paste proceed
        }
    }

    func stop() {
        guard let m = eventMonitor else { return }
        NSEvent.removeMonitor(m)
        eventMonitor = nil
    }

    deinit { stop() }

    // MARK: Pasteboard reading (image always wins over filename / URL)

    private func imageFromPasteboard() -> PendingAttachment? {
        let pb = NSPasteboard.general

        // 1. File URLs — checked FIRST because Finder also puts a low-res TIFF
        //    thumbnail of the file icon on the pasteboard. If we read pixel data
        //    first we'd get that tiny icon rather than the actual image file.
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: opts) as? [URL] {
            for url in urls where url.isImageFile {
                if let ns = NSImage(contentsOf: url),
                   let attachment = normalizedAttachment(from: ns) {
                    return attachment
                }
            }
        }

        // 2. Direct pixel data — covers screenshots, web-copied images, etc.
        //    These have no file URL so they always reach this branch correctly.
        let pixelTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
        ]
        for type in pixelTypes {
            if let data = pb.data(forType: type),
               let attachment = normalizedAttachment(from: data) {
                return attachment
            }
        }

        return nil
    }

    private func normalizedAttachment(from data: Data) -> PendingAttachment? {
        guard let ns = NSImage(data: data) else { return nil }
        return normalizedAttachment(from: ns)
    }

    private func normalizedAttachment(from ns: NSImage) -> PendingAttachment? {
        guard let tiff = ns.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        else { return nil }
        return PendingAttachment(data: jpeg, fileExtension: "jpg")
    }
}

private extension URL {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp",
    ]
    var isImageFile: Bool {
        Self.imageExtensions.contains(pathExtension.lowercased())
    }
}

#endif // os(macOS)
