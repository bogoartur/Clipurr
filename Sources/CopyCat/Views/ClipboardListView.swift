// ClipboardListView.swift
// CopyCat
//
// Scrollable list of clipboard history items with keyboard navigation.
// Renders `ClipboardRowView` for each item, supports arrow-key focus,
// Enter to re-copy, Escape to dismiss, Space to toggle the shared
// `ClipboardItemPreview` popover, and Cmd+1…Cmd+9 quick-paste.

import SwiftUI
import AppKit

/// A scrollable list of clipboard history items with keyboard navigation,
/// preview handling, and quick-paste support.
///
/// This view owns the single `isShowingPreview` / `previewItem` state used
/// by both the Force Touch deep press and the Space-key preview paths so
/// that both entry points drive the same `ClipboardItemPreview` surface
/// (Req 13.1–13.2, 13.6).
///
/// - Requirements: 3.1, 3.6, 8.2, 8.3, 8.4, 11.5, 11.6, 11.7, 11.8,
///   13.1, 13.2, 13.4, 13.5, 13.6, 14.4
struct ClipboardListView: View {

    // MARK: - Inputs

    /// The filtered list of clipboard items to display.
    let items: [ClipboardItem]

    /// Dependencies injected from `PopoverView` so quick-paste can resolve
    /// everything it needs without a separate DI container.
    @Bindable var store: HistoryStore
    var monitor: ClipboardMonitor
    var preferences: PreferencesStore
    var autoPasteService: AutoPasteService

    /// Syntax highlighter used by the shared `ClipboardItemPreview`. Kept
    /// here so the list can construct the preview at the list level.
    var syntaxHighlighter: any SyntaxHighlighter = PlainMonospaceHighlighter()

    /// Callback invoked when the user selects (clicks or presses Enter on)
    /// an item to re-copy it.
    let onSelect: (ClipboardItem) -> Void

    /// Callback invoked when the user deletes an item via the context menu.
    let onDelete: (ClipboardItem) -> Void

    /// Callback invoked when the user toggles the pin state of an item.
    let onTogglePin: (ClipboardItem) -> Void

    /// Callback invoked when a drag originating in a row begins.
    ///
    /// `PopoverView` uses this to flip the popover's `NSPopover.behavior`
    /// to `.applicationDefined` for the duration of the drag (Req 14.4);
    /// the matching `.transient` restoration is driven by a local mouse-up
    /// event monitor owned by `PopoverView`, since SwiftUI's `.onDrag`
    /// modifier does not expose an end-of-drag callback.
    let onDragStarted: () -> Void

    /// Callback invoked when the user presses Escape with no preview open
    /// (or, via the quick-paste handler, after a successful re-copy).
    let onDismiss: () -> Void

    // MARK: - Local state

    /// Tracks which item index currently has keyboard focus.
    @FocusState private var focusedIndex: Int?

    /// Whether the shared preview popover is presented.
    @State private var isShowingPreview: Bool = false

    /// The item currently displayed in the preview popover.
    @State private var previewItem: ClipboardItem?

    /// The id of the row anchor that should present the preview popover.
    /// Attaching `.popover` at a row-level anchor keeps the arrow pointing
    /// at the originating row rather than the list container.
    @State private var previewAnchorID: UUID?

    // MARK: - Body

    var body: some View {
        Group {
            if items.isEmpty {
                emptyPlaceholder
            } else {
                itemList
            }
        }
        .onKeyPress(.upArrow) {
            if isShowingPreview { return .ignored }
            moveFocus(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            if isShowingPreview { return .ignored }
            moveFocus(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if isShowingPreview { return .ignored }
            selectFocusedItem()
            return .handled
        }
        .onKeyPress(.escape) {
            if isShowingPreview {
                isShowingPreview = false
                return .handled
            }
            onDismiss()
            return .handled
        }
        .onKeyPress(.space) {
            if isShowingPreview {
                isShowingPreview = false
                return .handled
            }
            guard let index = focusedIndex, items.indices.contains(index) else {
                // Let the space key propagate (e.g. to the search field).
                return .ignored
            }
            presentPreview(for: index)
            return .handled
        }
        // Single `.onKeyPress(phases: .down)` captures every character key
        // press; we filter to Cmd+digit inside the handler because SwiftUI's
        // `.onKeyPress(keys:)` doesn't reliably gate on modifier flags on
        // macOS 14+.
        .onKeyPress(phases: .down) { press in
            guard press.modifiers.contains(.command),
                  let digit = Int(press.characters),
                  (1...9).contains(digit) else {
                return .ignored
            }
            return quickPasteHandler(digit)
        }
    }

    // MARK: - Empty State

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No items copied yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Copy something to see it here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            isFocused: focusedIndex == index,
                            onSelect: { onSelect(item) },
                            onDelete: { onDelete(item) },
                            onTogglePin: { onTogglePin(item) },
                            onRequestPreview: { presentPreview(for: index) },
                            onDragStarted: onDragStarted
                        )
                        .id(item.id)
                        .focused($focusedIndex, equals: index)
                        .popover(
                            isPresented: Binding(
                                get: { isShowingPreview && previewAnchorID == item.id },
                                set: { newValue in
                                    if !newValue { isShowingPreview = false }
                                }
                            ),
                            arrowEdge: .trailing
                        ) {
                            if let previewItem {
                                ClipboardItemPreview(
                                    item: previewItem,
                                    syntaxHighlighter: syntaxHighlighter
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: focusedIndex) { _, newIndex in
                if let newIndex, newIndex >= 0, newIndex < items.count {
                    withAnimation {
                        proxy.scrollTo(items[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Preview Presentation

    /// Sets the preview anchor / item / presentation flag so the row at
    /// `index` opens the shared `ClipboardItemPreview` popover.
    private func presentPreview(for index: Int) {
        guard items.indices.contains(index) else { return }
        previewItem = items[index]
        previewAnchorID = items[index].id
        isShowingPreview = true
    }

    // MARK: - Keyboard Navigation

    /// Moves the focused index by the given offset, clamping to valid bounds.
    private func moveFocus(by offset: Int) {
        guard !items.isEmpty else { return }

        if let current = focusedIndex {
            let newIndex = current + offset
            focusedIndex = max(0, min(newIndex, items.count - 1))
        } else {
            // No item focused yet — focus the first item on down, last on up
            focusedIndex = offset > 0 ? 0 : items.count - 1
        }
    }

    /// Re-copies the currently focused item, if any.
    private func selectFocusedItem() {
        guard let index = focusedIndex,
              index >= 0,
              index < items.count else { return }
        onSelect(items[index])
    }

    // MARK: - Quick Paste

    /// Re-copies `filteredItems[digit - 1]` through the store, optionally
    /// synthesizes a paste into the previously-frontmost app, and dismisses
    /// the popover. Out-of-bounds digits are absorbed silently — the event
    /// is still treated as handled so it doesn't leak to the search field
    /// or any other key responder (Req 11.6).
    private func quickPasteHandler(_ digit: Int) -> KeyPress.Result {
        let index = digit - 1
        guard items.indices.contains(index) else {
            return .handled
        }
        let target = items[index]
        store.recopy(target, writer: monitor, format: preferences.defaultRecopyFormat)
        if preferences.autoPasteEnabled {
            autoPasteService.pasteIntoPreviousApp()
        }
        onDismiss()
        return .handled
    }
}
