// ClipboardRowView.swift
// Clipurr
//
// Displays a single ClipboardItem row with Liquid Glass styling,
// text/image/file preview, a pin-state overlay, a relative timestamp,
// context menu, Force Touch deep-press, and drag-out support.
//
// This view is intentionally stateless about the preview popover —
// `ClipboardListView` owns the single `isShowingPreview` state and the
// list-level `.popover` so that both the Space key and the Force Touch
// deep press drive the same preview surface (Req 13.1–13.2, 13.6).

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// A row view displaying a single clipboard history item.
///
/// Shows a text preview (truncated to 80 characters), an image thumbnail,
/// or a file row (icon, name, optional `+N more` suffix, stale indicator)
/// plus a relative timestamp. When pinned, a `pin.fill` indicator is
/// overlaid in the top-leading corner. Supports:
/// - Plain click (fires `onSelect`)
/// - Force Touch deep press (fires `onRequestPreview`)
/// - Right-click context menu: Quick Look, Pin/Unpin, Reveal in Finder
///   (file items only), Delete
/// - `.onDrag` that returns an `NSItemProvider` with the correct payload
///   for the item's content kind (Req 14.1–14.3, 14.6), and notifies the
///   parent via `onDragStarted()` so the popover can keep itself visible
///   for the duration of the drag (Req 14.4)
struct ClipboardRowView: View {

    // MARK: - Inputs

    let item: ClipboardItem
    let isFocused: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRequestPreview: () -> Void
    let onDragStarted: () -> Void

    // MARK: - Local UI state

    @State private var isHovered: Bool = false

    private var isHighlighted: Bool { isFocused || isHovered }

    // MARK: - Body

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
        .overlay(alignment: .topLeading) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
                    .padding(4)
            }
        }
        .overlay {
            // Hit-testing layer for plain click + Force Touch deep press.
            // Deep press routes through `onRequestPreview` so the list can
            // own the single shared `isShowingPreview` state.
            PressureClickCatcher(
                onClick: onSelect,
                onDeepPress: onRequestPreview
            )
        }
        .onHover { isHovered = $0 }
        .onDrag {
            // Notify the popover that a drag began so it can flip its
            // behavior to `.applicationDefined` and stay visible for the
            // duration of the drag (Req 14.4). The provider itself carries
            // the row's payload.
            onDragStarted()
            return makeItemProvider()
        }
        .contextMenu {
            Button {
                onRequestPreview()
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            Button {
                onTogglePin()
            } label: {
                Label(
                    item.isPinned ? "Unpin" : "Pin",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }
            if case .file(let urls) = item.content {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: {
                    Label("Reveal in Finder", systemImage: "magnifyingglass")
                }
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

        case .file(let urls):
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: urls[0].path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(urls[0].lastPathComponent)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(fileLabelIsStale(urls[0]) ? .secondary : .primary)
                        .strikethrough(fileLabelIsStale(urls[0]))
                    if urls.count > 1 {
                        Text("+\(urls.count - 1) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Whether the given file URL no longer resolves to an existing file.
    /// Used to render a stale-state strikethrough on the row label (Req 17.7).
    private func fileLabelIsStale(_ url: URL) -> Bool {
        !FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Drag Payload

    /// Builds an `NSItemProvider` carrying the correct payload for this
    /// row's content kind.
    ///
    /// - `.text`: plain string, plus RTF and HTML data representations when
    ///   the item captured them (Req 14.1, 14.6).
    /// - `.image`: NSImage wrapping the PNG data (Req 14.2).
    /// - `.file`: single-URL provider via `NSItemProvider(contentsOf:)` for
    ///   the first URL (Req 14.3). Multi-file drag from a single provider
    ///   is macOS-complex; the first file is sufficient for the common case.
    private func makeItemProvider() -> NSItemProvider {
        switch item.content {
        case .text(let plain):
            let provider = NSItemProvider(object: plain as NSString)
            if let rtf = item.rtfData {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.rtf.identifier,
                    visibility: .all
                ) { completion in
                    completion(rtf, nil)
                    return nil
                }
            }
            if let html = item.htmlData {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.html.identifier,
                    visibility: .all
                ) { completion in
                    completion(html, nil)
                    return nil
                }
            }
            return provider
        case .image(let data):
            return NSItemProvider(object: NSImage(data: data) ?? NSImage())
        case .file(let urls):
            return NSItemProvider(contentsOf: urls[0]) ?? NSItemProvider()
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
