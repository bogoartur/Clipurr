// PopoverView.swift
// CopyCat
//
// Root SwiftUI view displayed inside the menu bar popover.
// Wraps SearchBarView, ClipboardListView, and a "Clear All" button
// in a GlassEffectContainer for Liquid Glass morphing and performance.

import SwiftUI

/// The root view displayed inside the menu bar popover.
///
/// Composes the search bar, clipboard history list, and a "Clear All" button.
/// Wrapped in a `GlassEffectContainer` for Liquid Glass styling. On item click,
/// re-copies the item with brief highlight feedback, then dismisses the popover.
///
/// - Requirements: 3.1, 3.5, 4.1, 4.2, 4.3, 4.4, 5.3, 5.4, 7.1, 7.3
struct PopoverView: View {
    @Bindable var store: HistoryStore
    var monitor: ClipboardMonitor
    var onDismiss: () -> Void

    /// The item currently showing a highlight animation after being re-copied.
    @State private var highlightedItemID: UUID?

    /// Whether the "Clear All" confirmation dialog is presented.
    @State private var showClearConfirmation = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Search bar at the top
                SearchBarView(
                    searchQuery: $store.searchQuery,
                    matchCount: store.matchCount
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Clipboard history list
                ClipboardListView(
                    items: store.filteredItems,
                    onSelect: { item in
                        recopyWithFeedback(item)
                    },
                    onDelete: { item in
                        store.deleteItem(item)
                    },
                    onDismiss: onDismiss
                )

                // Footer toolbar
                footerBar
            }
        }
        .frame(width: 340, height: 500)
        .confirmationDialog(
            "Clear Clipboard History",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                store.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove all clipboard items? This cannot be undone.")
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text(itemCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Button {
                showClearConfirmation = true
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(store.items.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var itemCountLabel: String {
        let count = store.items.count
        if count == 0 { return "No items" }
        if count == 1 { return "1 item" }
        return "\(count) items"
    }

    // MARK: - Re-copy with Highlight Feedback

    /// Re-copies the selected item, shows a brief highlight animation, then dismisses.
    private func recopyWithFeedback(_ item: ClipboardItem) {
        store.recopy(item, writer: monitor)

        // Show brief highlight animation before dismissing
        withAnimation(.easeInOut(duration: 0.15)) {
            highlightedItemID = item.id
        }

        // Dismiss after a short delay to let the user see the feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            highlightedItemID = nil
            onDismiss()
        }
    }
}
