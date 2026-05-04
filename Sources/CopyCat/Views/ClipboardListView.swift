// ClipboardListView.swift
// CopyCat
//
// Scrollable list of clipboard history items with keyboard navigation.
// Renders ClipboardRowView for each item, supports arrow-key focus,
// Enter to re-copy, and Escape to dismiss.

import SwiftUI

/// A scrollable list of clipboard history items with keyboard navigation support.
///
/// Uses `ScrollView` + `LazyVStack` to render `ClipboardRowView` for each item.
/// Arrow keys move focus through the list, Enter re-copies the focused item,
/// and Escape dismisses the popover.
///
/// - Requirements: 3.1, 3.6, 8.2, 8.3, 8.4
struct ClipboardListView: View {
    /// The filtered list of clipboard items to display.
    let items: [ClipboardItem]

    /// Callback invoked when the user selects (clicks or presses Enter on) an item to re-copy it.
    let onSelect: (ClipboardItem) -> Void

    /// Callback invoked when the user deletes an item via the context menu.
    let onDelete: (ClipboardItem) -> Void

    /// Callback invoked when the user presses Escape to dismiss the popover.
    let onDismiss: () -> Void

    /// Tracks which item index currently has keyboard focus.
    @FocusState private var focusedIndex: Int?

    var body: some View {
        Group {
            if items.isEmpty {
                emptyPlaceholder
            } else {
                itemList
            }
        }
        .onKeyPress(.upArrow) {
            moveFocus(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveFocus(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            selectFocusedItem()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
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
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            isFocused: focusedIndex == index,
                            onDelete: { onDelete(item) }
                        )
                        .id(index)
                        .focused($focusedIndex, equals: index)
                        .onTapGesture {
                            onSelect(item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: focusedIndex) { _, newIndex in
                if let newIndex {
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
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
}
