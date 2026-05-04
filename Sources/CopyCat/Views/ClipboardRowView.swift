// ClipboardRowView.swift
// CopyCat
//
// Displays a single ClipboardItem row with Liquid Glass styling,
// text/image preview, relative timestamp, and context menu support.

import SwiftUI
import AppKit

/// A row view displaying a single clipboard history item with Liquid Glass styling.
///
/// Shows a text preview (truncated to 80 characters) or image thumbnail,
/// a relative timestamp, and supports right-click context menu for deletion.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let isFocused: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            contentPreview
            Spacer()
            timestampLabel
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isFocused ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .glassEffect(.regular.interactive())
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text:
            Text(item.textPreview)
                .lineLimit(1)
                .font(.body)
                .truncationMode(.tail)

        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60)
            } else {
                Text("[Image]")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Timestamp

    private var timestampLabel: some View {
        Text(relativeTimestamp)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }
}
