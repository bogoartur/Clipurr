// ContentTypeExtractor.swift
// CopyCat
//
// Pure function over an `NSPasteboard` that returns the richest available
// representation of the current clipboard payload: file URLs, text (with
// optional RTF/HTML rich variants), or a PNG image. Returns `nil` when no
// recognized type is present.
//
// Priority order (per design §ContentTypeExtractor):
//   1. File URLs via `public.file-url`
//   2. Text (with optional rich variants alongside)
//   3. Image (PNG, or TIFF converted to PNG)
//
// NOTE: This module deliberately does not rewire `ClipboardMonitor` yet —
// the monitor continues to read the pasteboard directly until task 18.1.

import Foundation
import AppKit
import UniformTypeIdentifiers
import os.log

// MARK: - ClipboardItemRepresentation

/// Richest-available shape produced by `ContentTypeExtractor` and handed to
/// `HistoryStore` via the extended `addRepresentation(_:)` path (task 17.1).
///
/// Kept at file scope — not nested in the enum — so `ClipboardMonitor` and
/// `HistoryStore` can refer to it directly without qualifying through
/// `ContentTypeExtractor`.
struct ClipboardItemRepresentation: Equatable {
    enum Payload: Equatable {
        case text(plain: String, rtf: Data?, html: Data?)
        case image(Data)
        case file([URL])
    }

    let payload: Payload
}

// MARK: - Pasteboard type helpers

private extension NSPasteboard.PasteboardType {
    /// macOS does not ship a stock `NSPasteboard.PasteboardType.html`, so
    /// define it here against the UTI string used by `public.html`.
    static let html = NSPasteboard.PasteboardType("public.html")
}

// MARK: - ContentTypeExtractor

enum ContentTypeExtractor {

    // MARK: - Constants

    /// Maximum image size in bytes (10 MB). Matches the existing
    /// `ClipboardMonitor` cap so behavior stays identical after the
    /// monitor is rewired to use this extractor (task 18.1).
    static let maxImageSize: Int = 10 * 1024 * 1024

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "ContentTypeExtractor"
    )

    // MARK: - Extract

    /// Reads the richest available representation from `pasteboard`.
    ///
    /// Returns `nil` when the pasteboard holds no recognized content or when
    /// an image payload exceeds `maxImageSize` (the monitor's existing skip
    /// behavior).
    static func extract(from pasteboard: NSPasteboard) -> ClipboardItemRepresentation? {
        // 1. File URLs take priority over text and image.
        if let urls = readFileURLs(from: pasteboard), !urls.isEmpty {
            return ClipboardItemRepresentation(payload: .file(urls))
        }

        // 2. Text (plain and/or rich variants).
        if let textPayload = readTextPayload(from: pasteboard) {
            return ClipboardItemRepresentation(payload: textPayload)
        }

        // 3. Image (PNG preferred; TIFF converted to PNG).
        if let imageData = readImageData(from: pasteboard) {
            return ClipboardItemRepresentation(payload: .image(imageData))
        }

        return nil
    }

    // MARK: - File URLs

    /// Reads file URLs from the pasteboard, keeping only entries whose
    /// `isFileURL` is `true` so generic `https://` URLs do not get captured
    /// as file items.
    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return nil
        }
        let fileURLs = objects.filter { $0.isFileURL }
        return fileURLs.isEmpty ? nil : fileURLs
    }

    // MARK: - Text + Rich

    /// Reads plain text plus any available RTF / HTML rich variants.
    ///
    /// When plain text is missing but a rich variant is present, derives the
    /// plain string from the rich data via `NSAttributedString`. If rich
    /// data is present but undecodable, the rich variant is dropped and the
    /// other branches still apply.
    private static func readTextPayload(from pasteboard: NSPasteboard) -> ClipboardItemRepresentation.Payload? {
        let plain = pasteboard.string(forType: .string)
        let rtf = pasteboard.data(forType: .rtf)
        let html = pasteboard.data(forType: .html)

        // Bail out if the pasteboard has no text-like content at all.
        if (plain == nil || plain?.isEmpty == true) && rtf == nil && html == nil {
            return nil
        }

        // Resolve a plain-text string: prefer the pasteboard's own `.string`;
        // otherwise derive from RTF, then HTML.
        let resolvedPlain: String? = {
            if let plain = plain, !plain.isEmpty {
                return plain
            }
            if let rtf = rtf, let derived = decodeAttributedString(from: rtf, documentType: .rtf) {
                return derived
            }
            if let html = html, let derived = decodeAttributedString(from: html, documentType: .html) {
                return derived
            }
            return nil
        }()

        guard let resolvedPlain = resolvedPlain, !resolvedPlain.isEmpty else {
            return nil
        }

        return .text(plain: resolvedPlain, rtf: rtf, html: html)
    }

    /// Decodes `data` as an `NSAttributedString` using the given document
    /// type and returns its plain-text `string`, or `nil` on failure.
    private static func decodeAttributedString(
        from data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> String? {
        do {
            let attr = try NSAttributedString(
                data: data,
                options: [.documentType: documentType],
                documentAttributes: nil
            )
            return attr.string
        } catch {
            logger.warning("Failed to decode rich text (\(String(describing: documentType), privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Image

    /// Reads image data from the pasteboard, preferring an already-encoded
    /// PNG and falling back to converting TIFF via `NSBitmapImageRep`.
    /// Returns `nil` when the resulting PNG exceeds `maxImageSize` so the
    /// monitor continues to skip oversized images.
    private static func readImageData(from pasteboard: NSPasteboard) -> Data? {
        if let pngData = pasteboard.data(forType: .png) {
            guard pngData.count <= maxImageSize else {
                logger.warning("Skipping image: PNG data exceeds 10 MB (\(pngData.count, privacy: .public) bytes)")
                return nil
            }
            return pngData
        }

        if let tiffData = pasteboard.data(forType: .tiff) {
            guard let imageRep = NSBitmapImageRep(data: tiffData) else {
                logger.warning("Failed to create NSBitmapImageRep from TIFF data")
                return nil
            }
            guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
                logger.warning("Failed to convert NSBitmapImageRep to PNG representation")
                return nil
            }
            guard pngData.count <= maxImageSize else {
                logger.warning("Skipping image: converted PNG data exceeds 10 MB (\(pngData.count, privacy: .public) bytes)")
                return nil
            }
            return pngData
        }

        return nil
    }
}
