// ClipboardItemPreview.swift
// Clipurr
//
// The one-and-only `Detail_Preview` component shown both by Force Touch
// deep press (from `ClipboardRowView`) and by Space-key preview (from
// `ClipboardListView`). Renders:
//   - Text items: prefers rich variants (RTF/HTML → `NSAttributedString`),
//     otherwise runs `CodeDetector` and — when the source looks like code —
//     pipes it through the injected `SyntaxHighlighter`. Falls back to a
//     plain monospaced view.
//   - Image items: full-size image plus a "Recognized Text" disclosure
//     when `ocrText` is populated (Req 9.7).
//   - File items: large icon, file name, full path, optional list of
//     additional files, and a Liquid-Glass "Reveal in Finder" button.

import SwiftUI
import AppKit

/// A larger preview of a single `ClipboardItem`, designed to appear inside
/// a `.popover` presented at the list level.
struct ClipboardItemPreview: View {

    // MARK: - Inputs

    let item: ClipboardItem

    /// Syntax highlighter used when a text item has no rich variant but
    /// looks like source code. Defaults to the plain monospaced fallback.
    let syntaxHighlighter: any SyntaxHighlighter

    // MARK: - Init

    init(
        item: ClipboardItem,
        syntaxHighlighter: any SyntaxHighlighter = PlainMonospaceHighlighter()
    ) {
        self.item = item
        self.syntaxHighlighter = syntaxHighlighter
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Divider()

            content
        }
        .padding(12)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 520,
               minHeight: 160, idealHeight: 280, maxHeight: 420)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: headerIcon)
                .foregroundStyle(.secondary)
            Text(headerTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(metadataLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    private var headerIcon: String {
        switch item.content {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc.on.doc"
        }
    }

    private var headerTitle: String {
        switch item.content {
        case .text: return "Text"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    private var metadataLabel: String {
        switch item.content {
        case .text(let string):
            let chars = string.count
            let lines = string.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            return "\(chars) chars · \(lines) line\(lines == 1 ? "" : "s")"
        case .image(let data):
            var pieces: [String] = []
            if let rep = NSImage(data: data)?.representations.first {
                pieces.append("\(rep.pixelsWide)×\(rep.pixelsHigh)")
            }
            pieces.append(byteCountFormatter.string(fromByteCount: Int64(data.count)))
            return pieces.joined(separator: " · ")
        case .file(let urls):
            return urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .text(let string):
            textContent(string)

        case .image(let data):
            imageContent(data)

        case .file(let urls):
            fileContent(urls)
        }
    }

    // MARK: - Text Content (rich → code → plain)

    @ViewBuilder
    private func textContent(_ string: String) -> some View {
        if let rtf = item.rtfData,
           let attributed = attributedString(from: rtf, documentType: .rtf) {
            ScrollView {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let html = item.htmlData,
                  let attributed = attributedString(from: html, documentType: .html) {
            ScrollView {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            let verdict = CodeDetector.detect(string)
            if verdict.isCode {
                let ns = syntaxHighlighter.highlight(string, language: verdict.language)
                ScrollView {
                    Text(AttributedString(ns))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    Text(string)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Decodes `data` as the given document type and returns the resulting
    /// `AttributedString`, or `nil` on any decode failure so the caller can
    /// fall through to the plain-text branch.
    private func attributedString(
        from data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> AttributedString? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType
        ]
        guard let ns = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return nil
        }
        return AttributedString(ns)
    }

    // MARK: - Image Content (with optional OCR disclosure)

    @ViewBuilder
    private func imageContent(_ data: Data) -> some View {
        if let nsImage = NSImage(data: data) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let ocr = item.ocrText, !ocr.isEmpty {
                    DisclosureGroup("Recognized Text") {
                        ScrollView {
                            Text(ocr)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }
        } else {
            Text("Unable to display image")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - File Content

    @ViewBuilder
    private func fileContent(_ urls: [URL]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: urls[0].path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(urls[0].lastPathComponent)
                        .font(.headline)
                    Text(urls[0].path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
            }
            if urls.count > 1 {
                Divider()
                Text("\(urls.count) files total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(urls.dropFirst(), id: \.self) { url in
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private var byteCountFormatter: ByteCountFormatter {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB]
        f.countStyle = .file
        return f
    }
}
