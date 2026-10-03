// PopoverView.swift
// Clipurr
//
// Root SwiftUI view displayed inside the menu bar popover.
// Wraps SearchBarView, ClipboardListView, and a "Clear All" button
// in a GlassEffectContainer for Liquid Glass morphing and performance.
//
// Also owns the drag-state plumbing (Req 14.4): when a row-originated
// drag begins, `dragStateChanged(true)` is invoked so the `StatusBarController`
// can flip the `NSPopover.behavior` to `.applicationDefined`. A local
// `NSEvent` monitor watches for the next `leftMouseUp` to restore the
// default `.transient` behavior, since SwiftUI's `.onDrag` does not
// expose an end-of-drag callback on macOS.

import SwiftUI
import AppKit

/// The root view displayed inside the menu bar popover.
///
/// Composes the search bar, clipboard history list, and a "Clear All" button.
/// Wrapped in a `GlassEffectContainer` for Liquid Glass styling. On item click,
/// re-copies the item with brief highlight feedback, then dismisses the popover.
///
/// - Requirements: 3.1, 3.5, 4.1, 4.2, 4.3, 4.4, 5.3, 5.4, 7.1, 7.3,
///   11.8, 14.4
struct PopoverView: View {

    // MARK: - Inputs

    @Bindable var store: HistoryStore
    var monitor: ClipboardMonitor
    var preferences: PreferencesStore
    var autoPasteService: AutoPasteService

    /// Syntax highlighter passed through to `ClipboardListView` →
    /// `ClipboardItemPreview`. Defaults to the plain monospaced fallback so
    /// `AppDelegate` does not have to instantiate one until a concrete
    /// library is wired in.
    var syntaxHighlighter: any SyntaxHighlighter = PlainMonospaceHighlighter()

    var onDismiss: () -> Void

    /// Invoked by the list when a row-originated drag begins (`true`) and
    /// by the internal mouse-up monitor when that drag ends (`false`).
    /// Defaults to a no-op so existing call sites that do not supply a
    /// handler continue to compile.
    var dragStateChanged: (Bool) -> Void = { _ in }

    // MARK: - Local state

    /// The item currently showing a highlight animation after being re-copied.
    @State private var highlightedItemID: UUID?

    /// Whether the "Clear All" confirmation dialog is presented.
    @State private var showClearConfirmation = false

    /// Whether a row-originated drag is currently in flight.
    @State private var isDragInFlight: Bool = false

    /// Local `NSEvent` monitor used to detect the end of a drag via the
    /// next `leftMouseUp`. Retained here so `.onDisappear` can remove it.
    @State private var mouseUpMonitor: Any?

    // MARK: - Body

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
                    store: store,
                    monitor: monitor,
                    preferences: preferences,
                    autoPasteService: autoPasteService,
                    syntaxHighlighter: syntaxHighlighter,
                    onSelect: { item in
                        recopyWithFeedback(item)
                    },
                    onDelete: { item in
                        store.deleteItem(item)
                    },
                    onTogglePin: { item in
                        store.togglePin(item)
                    },
                    onDragStarted: {
                        if !isDragInFlight {
                            isDragInFlight = true
                            dragStateChanged(true)
                        }
                    },
                    onDismiss: onDismiss
                )

                // Footer toolbar
                footerBar
            }
        }
        .frame(width: 340, height: 500)
        .onAppear { installMouseUpMonitor() }
        .onDisappear { removeMouseUpMonitor() }
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
        store.recopy(item, writer: monitor, format: preferences.defaultRecopyFormat)

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

    // MARK: - Drag mouse-up monitor

    /// Installs a local mouse-up monitor that flips the drag-in-flight
    /// flag back off once a drag completes. SwiftUI's `.onDrag` modifier
    /// only signals the start of a drag; observing `leftMouseUp` gives us
    /// a reliable end-of-drag signal without needing an `NSDraggingDestination`.
    private func installMouseUpMonitor() {
        guard mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            if isDragInFlight {
                isDragInFlight = false
                dragStateChanged(false)
            }
            return event
        }
    }

    private func removeMouseUpMonitor() {
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }
    }
}
