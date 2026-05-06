// ClipboardItemPreview.swift
// CopyCat
//
// Expanded detail preview shown when the user long-presses a row.
// Text items render in a scrollable monospaced view with char/line
// counts; image items render at a larger size with dimension and
// data-size metadata.

import SwiftUI
import AppKit

/// A larger preview of a single `ClipboardItem`, designed to appear inside
/// a `.popover` when the user long-presses (or otherwise peeks at) a row.
struct ClipboardItemPreview: View {
    let item: ClipboardItem

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
        }
    }

    private var headerTitle: String {
        switch item.content {
        case .text: return "Text"
        case .image: return "Image"
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
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .text(let string):
            ScrollView {
                Text(string)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .image(let data):
            if let nsImage = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Text("Unable to display image")
                    .foregroundStyle(.secondary)
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
