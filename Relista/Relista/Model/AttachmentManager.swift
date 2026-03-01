//
//  AttachmentManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import Foundation

struct AttachmentRecord: Codable {
    let uuid: String
    let fileExtension: String
    var qaHistory: [ImageQA]
}

struct ImageQA: Codable {
    let question: String
    let answer: String
}

enum AttachmentManager {

    // MARK: - Paths

    static func attachmentsFolder(for conversationID: UUID) -> URL {
        ConversationManager.conversationsURL
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("attachments")
    }

    private static func indexURL(for conversationID: UUID) -> URL {
        attachmentsFolder(for: conversationID).appendingPathComponent("index.json")
    }

    // MARK: - Image I/O

    /// Saves image data to the per-conversation attachments folder and registers it in the index.
    /// Returns the filename (uuid.ext) that should be stored in Message.attachmentLinks.
    static func saveImage(_ data: Data, fileExtension: String, for conversationID: UUID) throws -> String {
        let folder = attachmentsFolder(for: conversationID)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let uuid = UUID().uuidString
        let filename = "\(uuid).\(fileExtension)"
        try data.write(to: folder.appendingPathComponent(filename))

        var records = loadIndex(for: conversationID)
        records.append(AttachmentRecord(uuid: uuid, fileExtension: fileExtension, qaHistory: []))
        try saveIndex(records, for: conversationID)

        return filename
    }

    /// Returns the file:// URL for an attachment filename.
    static func imageURL(filename: String, for conversationID: UUID) -> URL {
        attachmentsFolder(for: conversationID).appendingPathComponent(filename)
    }

    /// Loads raw image data for an attachment (returns nil if missing).
    static func loadImage(filename: String, for conversationID: UUID) -> Data? {
        try? Data(contentsOf: imageURL(filename: filename, for: conversationID))
    }

    // MARK: - Index

    static func loadIndex(for conversationID: UUID) -> [AttachmentRecord] {
        let url = indexURL(for: conversationID)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([AttachmentRecord].self, from: data)
        else { return [] }
        return records
    }

    static func saveIndex(_ records: [AttachmentRecord], for conversationID: UUID) throws {
        let folder = attachmentsFolder(for: conversationID)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(records).write(to: indexURL(for: conversationID))
    }

    // MARK: - Q&A History

    /// Appends a Q&A pair to an image's record. Silent no-op if the UUID is not found.
    static func addQA(imageUUID: String, question: String, answer: String, for conversationID: UUID) {
        var records = loadIndex(for: conversationID)
        guard let i = records.firstIndex(where: { $0.uuid == imageUUID }) else { return }
        records[i].qaHistory.append(ImageQA(question: question, answer: answer))
        try? saveIndex(records, for: conversationID)
    }

    // MARK: - Context Injection

    /// Builds the attachment context block injected into a message's API content.
    /// Returns nil if filenames is empty.
    static func attachmentContextBlock(for filenames: [String], in conversationID: UUID) -> String? {
        guard !filenames.isEmpty else { return nil }
        let index = loadIndex(for: conversationID)
        var lines: [String] = ["---", "Attachments in this message:"]

        for filename in filenames {
            let uuidPart = (filename as NSString).deletingPathExtension
            if let record = index.first(where: { $0.uuid == uuidPart }) {
                if record.qaHistory.isEmpty {
                    lines.append("- \(filename) — not yet analyzed. Use the analyze_image tool to examine it if relevant.")
                } else {
                    let n = record.qaHistory.count
                    lines.append("- \(filename) — \(n) previous \(n == 1 ? "analysis" : "analyses"):")
                    for (i, qa) in record.qaHistory.enumerated() {
                        lines.append("  Q\(i + 1): \"\(qa.question)\"")
                        lines.append("  A\(i + 1): \"\(qa.answer)\"")
                    }
                }
            } else {
                lines.append("- \(filename) — not yet analyzed. Use the analyze_image tool to examine it if relevant.")
            }
        }

        return lines.joined(separator: "\n")
    }
}
