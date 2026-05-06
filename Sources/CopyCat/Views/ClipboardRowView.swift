// ClipboardRowView.swift
// CopyCat
//
// Displays a single ClipboardItem row with Liquid Glass styling,
// text/image preview, relative timestamp, and context menu support.

import SwiftUI
import AppKit

/// A row view displaying a single clipboard history item.
///
/// Shows a text preview (truncated to 80 characters) or image thumbnail,
/// a relative timestamp, and supports right-click context menu for deletion.
/// Uses a subtle Liquid Glass highlight when focused or hovered.
/// A Force Touch (deep press) opens a larger detail preview on pressure-
/// sensitive trackpads; the context menu's Quick Look item is the fallback.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let isFocused: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var isShowingPreview: Bool = false

    private var isHighlighted: Bool { isFocused || isHovered || isShowingPreview }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            contentPreview
                .frame(maxWidth: .infinity, alignment: .leading)

            timestampLabel
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect(cornerRadius: 8))
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.selection)
            }
        }
        .overlay {
            // Hit-testing layer for plain click + Force Touch deep press.
            PressureClickCatcher(
                onClick: onSelect,
                onDeepPress: { isShowingPreview = true }
            )
        }
        .onHover { isHovered = $0 }
        .popover(isPresented: $isShowingPreview, arrowEdge: .trailing) {
            ClipboardItemPreview(item: item)
        }
        .contextMenu {
            Button {
                isShowingPreview = true
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
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
                .font(.system(size: 13))
                .truncationMode(.tail)
                .foregroundStyle(.primary)

        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 100)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text("Image")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Timestamp

    private var timestampLabel: some View {
        Text(relativeTimestamp)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }
}
