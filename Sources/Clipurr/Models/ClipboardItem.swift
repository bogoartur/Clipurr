// ClipboardItem.swift
// Clipurr
//
// Data models for clipboard history items.

import Foundation

/// Represents the content of a clipboard item — text, image data, or a
/// list of file URLs captured from the `public.file-url` pasteboard type.
enum ClipboardItemContent: Codable, Equatable {
    case text(String)
    case image(Data) // PNG data
    case file([URL])

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case text
        case image
        case file
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let textValue = try container.decodeIfPresent(String.self, forKey: .text) {
            self = .text(textValue)
        } else if let imageValue = try container.decodeIfPresent(Data.self, forKey: .image) {
            self = .image(imageValue)
        } else if let fileStrings = try container.decodeIfPresent([String].self, forKey: .file) {
            // Parse each entry with `URL(string:)` and drop invalid entries.
            let urls = fileStrings.compactMap { URL(string: $0) }
            guard !urls.isEmpty else {
                // Treat an empty or fully-unparseable file URL list as a
                // corrupted item so the surrounding history skips it rather
                // than silently creating an empty file item.
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath + [CodingKeys.file],
                        debugDescription: "File URL list was empty or unparseable in ClipboardItemContent"
                    )
                )
            }
            self = .file(urls)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'text', 'image', or 'file' key in ClipboardItemContent"
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
        case .file(let urls):
            try container.encode(urls.map(\.absoluteString), forKey: .file)
        }
    }
}

/// A single clipboard history entry.
///
/// The four extended fields (`isPinned`, `rtfData`, `htmlData`, `ocrText`)
/// are all optional / defaulted so that any pre-extension `history.json`
/// file still decodes cleanly via the custom `init(from:)` below.
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipboardItemContent
    /// Mutable so smart dedup (task 17.1) can promote an existing item to
    /// the top of the history by refreshing its timestamp.
    var createdAt: Date

    /// Whether the user has pinned this item. Pinned items sort above
    /// non-pinned ones and are exempt from history-cap / age-expiry eviction.
    var isPinned: Bool = false

    /// Rich Text Format bytes captured from the pasteboard when available.
    var rtfData: Data? = nil

    /// HTML bytes captured from the pasteboard when available.
    var htmlData: Data? = nil

    /// Text extracted from an image item by the OCR service. Populated
    /// asynchronously after the item is added to the history.
    var ocrText: String? = nil

    // MARK: - Init

    /// Memberwise initializer with defaults for the extended fields so
    /// existing call sites `ClipboardItem(id:content:createdAt:)` continue
    /// to compile unchanged.
    init(
        id: UUID,
        content: ClipboardItemContent,
        createdAt: Date,
        isPinned: Bool = false,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.ocrText = ocrText
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdAt
        case isPinned
        case rtfData
        case htmlData
        case ocrText
    }

    /// Custom decoder that tolerates JSON documents written before the
    /// extended fields existed. Each new field decodes via `decodeIfPresent`
    /// and falls back to the default defined above.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.content = try container.decode(ClipboardItemContent.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        self.htmlData = try container.decodeIfPresent(Data.self, forKey: .htmlData)
        self.ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
    }

    // `encode(to:)` is synthesized by the compiler and emits every stored
    // property as a JSON key, which is exactly what we want for forward
    // compatibility — older readers that use `decodeIfPresent` ignore keys
    // they don't know about.

    // MARK: - textPreview

    /// A short text preview suitable for display in the history list.
    ///
    /// For text items, strips leading whitespace and newlines (so a code
    /// snippet that begins with a blank line still shows meaningful content),
    /// then returns the first line truncated to 80 characters with a trailing
    /// ellipsis (`…`) when content is longer or spans multiple lines.
    /// For image items, returns `"[Image]"`.
    /// For file items, returns the first URL's `lastPathComponent`, with a
    /// `" +N more"` suffix when the item references more than one file.
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
        case .file(let urls):
            // The decoder guarantees a non-empty URL list for `.file`, but
            // guard defensively so a programmatically-constructed empty list
            // still produces a sensible label.
            guard let first = urls.first else { return "[Files]" }
            let name = first.lastPathComponent
            if urls.count > 1 {
                return name + " +\(urls.count - 1) more"
            }
            return name
        }
    }
}
