// ClipboardItem.swift
// CopyCat
//
// Data models for clipboard history items.

import Foundation

/// Represents the content of a clipboard item — either text or image data.
enum ClipboardItemContent: Codable, Equatable {
    case text(String)
    case image(Data) // PNG data

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let textValue = try container.decodeIfPresent(String.self, forKey: .text) {
            self = .text(textValue)
        } else if let imageValue = try container.decodeIfPresent(Data.self, forKey: .image) {
            self = .image(imageValue)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'text' or 'image' key in ClipboardItemContent"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode(string, forKey: .text)
        case .image(let data):
            try container.encode(data, forKey: .image)
        }
    }
}

/// A single clipboard history entry.
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipboardItemContent
    let createdAt: Date

    /// A short text preview suitable for display in the history list.
    ///
    /// For text items, strips leading whitespace and newlines (so a code
    /// snippet that begins with a blank line still shows meaningful content),
    /// then returns the first line truncated to 80 characters with a trailing
    /// ellipsis (`…`) when content is longer or spans multiple lines.
    /// For image items, returns `"[Image]"`.
    var textPreview: String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return string }

            // Collapse to the first non-empty line for the list preview.
            let firstLine = trimmed
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? trimmed

            let hasMoreContent = firstLine.count < trimmed.count

            if firstLine.count > 80 {
                return String(firstLine.prefix(79)) + "…"
            }
            return hasMoreContent ? firstLine + "…" : firstLine
        case .image:
            return "[Image]"
        }
    }
}
