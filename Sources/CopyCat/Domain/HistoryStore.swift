// HistoryStore.swift
// CopyCat
//
// Manages the in-memory clipboard history and coordinates persistence.
//
// Tasks 17.1–17.7 extend the baseline store with smart dedup, pin/unpin,
// OCR-aware filtering + pinned-first sort, configurable cap and age-based
// expiry, idempotent OCR application, and rich-preserving re-copy.

import Foundation
import AppKit
import os.log

// MARK: - ClipboardWritable Protocol

/// Protocol for clipboard write coordination.
/// `ClipboardMonitor` will conform to this so that re-copy operations
/// can signal the monitor to ignore the self-initiated pasteboard change.
protocol ClipboardWritable {
    func setIgnoreSelfWrite()
}

// MARK: - HistoryStore

/// The central store for clipboard history items.
///
/// Holds a single `items` array of `ClipboardItem` values. The visible
/// ordering for the UI is produced by `filteredItems`, which sorts pinned
/// items above non-pinned items and then newest-first. Internally the
/// array is kept newest-first among non-pinned items so eviction remains
/// trivially correct.
@Observable
final class HistoryStore {

    // MARK: - Constants

    /// Default maximum number of non-pinned items retained. `PreferencesStore`
    /// may override this at runtime via `enforceCap(_:)`.
    static let maxItems = 50

    // MARK: - Stored Properties

    /// The full clipboard history.
    ///
    /// Ordering is not strictly maintained; `filteredItems` is the source of
    /// truth for what the UI shows. Non-pinned items trend toward newest-
    /// first because `addRepresentation` prepends, but pinned items stay
    /// wherever the user pinned them.
    private(set) var items: [ClipboardItem] = []

    /// The current search filter text entered by the user.
    var searchQuery: String = ""

    /// In-memory cache of OCR text keyed by item id; kept in sync with
    /// `ClipboardItem.ocrText` by `applyOCR(_:to:)`.
    @ObservationIgnored
    let ocrIndex = OCRIndex()

    /// The active history-cap policy. Defaults to `.finite(50)`; `AppDelegate`
    /// updates this from `PreferencesStore` at launch and on every change.
    @ObservationIgnored
    var currentCap: HistoryCap = .finite(HistoryStore.maxItems)

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "HistoryStore"
    )

    // MARK: - Computed Properties

    /// Items matching the current search query, sorted pinned-first then
    /// newest-first.
    ///
    /// When `searchQuery` is empty, every item is included. When non-empty,
    /// the filter is case-insensitive and matches:
    /// - `.text(s)` when `s` contains the query, OR when the item's
    ///   `ocrText` contains the query (images with OCR are still excluded).
    /// - `.image` when the item's `ocrText` contains the query.
    /// - `.file(urls)` when any URL's `lastPathComponent` or full `path`
    ///   contains the query.
    ///
    /// After filtering, items are sorted with `isPinned == true` first, then
    /// by `createdAt` descending.
    var filteredItems: [ClipboardItem] {
        let base: [ClipboardItem]
        if searchQuery.isEmpty {
            base = items
        } else {
            base = items.filter { matches(query: searchQuery, item: $0) }
        }

        return base.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    /// The number of items matching the current search filter.
    var matchCount: Int {
        filteredItems.count
    }

    /// Whether the given item's text, OCR text, or file URLs match `query`.
    private func matches(query: String, item: ClipboardItem) -> Bool {
        switch item.content {
        case .text(let s):
            if s.localizedCaseInsensitiveContains(query) { return true }
            return item.ocrText?.localizedCaseInsensitiveContains(query) ?? false
        case .image:
            return item.ocrText?.localizedCaseInsensitiveContains(query) ?? false
        case .file(let urls):
            return urls.contains { url in
                url.lastPathComponent.localizedCaseInsensitiveContains(query)
                    || url.path.localizedCaseInsensitiveContains(query)
            }
        }
    }

    // MARK: - Mutations — Baseline (retained for back-compat)

    /// Adds new clipboard content to the history.
    ///
    /// This baseline entry point is kept so the existing `ClipboardMonitor`
    /// wiring (and the `addItem` unit tests from tasks 3.x) continue to
    /// work unchanged. Internally it builds a `ClipboardItemRepresentation`
    /// with no rich variants and delegates to `addRepresentation(_:)`.
    ///
    /// - Parameter content: The clipboard content to add.
    func addItem(_ content: ClipboardItemContent) {
        let payload: ClipboardItemRepresentation.Payload
        switch content {
        case .text(let s):
            payload = .text(plain: s, rtf: nil, html: nil)
        case .image(let data):
            payload = .image(data)
        case .file(let urls):
            payload = .file(urls)
        }
        addRepresentation(ClipboardItemRepresentation(payload: payload))
    }

    // MARK: - Mutations — Extended (task 17.1)

    /// Adds a new clipboard representation to the history with smart dedup.
    ///
    /// Behavior (Requirements 16.1–16.4, 2.x preserved for the no-match case):
    /// 1. Build the candidate `ClipboardItemContent` from the representation.
    /// 2. If any **non-pinned** item in history has equal content:
    ///    - Remove it from its current index.
    ///    - Update its `createdAt` to `Date()` (promotion refreshes the timestamp).
    ///    - Merge in any newly-present `rtfData` / `htmlData` from the new
    ///      representation when the existing item lacked them.
    ///    - Re-insert at index 0.
    ///    - Total history count is unchanged; no new item is created.
    /// 3. If any **pinned** item has equal content, leave the pinned item
    ///    in place and still apply step 2 against non-pinned items so no
    ///    new non-pinned duplicate is created.
    /// 4. Otherwise, prepend a brand-new `ClipboardItem`.
    /// 5. Enforce the active `currentCap` (pinned items exempt).
    /// 6. Persist to disk.
    ///
    /// - Returns: The `UUID` of the item that was created or promoted to
    ///   index 0, or `nil` when the new content matched an existing pinned
    ///   item and no change was made. Callers use the returned id to target
    ///   follow-up updates such as OCR results.
    @discardableResult
    func addRepresentation(_ representation: ClipboardItemRepresentation) -> UUID? {
        let candidateContent = content(from: representation)
        let now = Date()

        // Rich variants arriving with this representation, if any.
        let incomingRTF: Data?
        let incomingHTML: Data?
        if case .text(_, let rtf, let html) = representation.payload {
            incomingRTF = rtf
            incomingHTML = html
        } else {
            incomingRTF = nil
            incomingHTML = nil
        }

        // Step 2/3: promote an existing non-pinned match; ignore pinned matches
        // but do not create a new non-pinned duplicate of pinned content.
        if let existingIndex = items.firstIndex(where: {
            !$0.isPinned && $0.content == candidateContent
        }) {
            var promoted = items.remove(at: existingIndex)
            promoted.createdAt = now
            // Merge rich variants forward when the existing item lacked them.
            if promoted.rtfData == nil, let incomingRTF { promoted.rtfData = incomingRTF }
            if promoted.htmlData == nil, let incomingHTML { promoted.htmlData = incomingHTML }
            items.insert(promoted, at: 0)
            saveToDisk()
            return promoted.id
        }

        // Content equals a pinned item's content (no non-pinned duplicate
        // should be created, per Requirement 16.3).
        let matchesPinned = items.contains { $0.isPinned && $0.content == candidateContent }
        if matchesPinned {
            // Nothing to do — pinned item stays put, no new duplicate added.
            return nil
        }

        // Step 4: prepend a new item.
        let newItem = ClipboardItem(
            id: UUID(),
            content: candidateContent,
            createdAt: now,
            isPinned: false,
            rtfData: incomingRTF,
            htmlData: incomingHTML,
            ocrText: nil
        )
        items.insert(newItem, at: 0)

        // Step 5: enforce the cap (non-pinned only).
        enforceCap(currentCap)

        // Step 6: persist.
        saveToDisk()
        return newItem.id
    }

    /// Extracts the `ClipboardItemContent` equivalent of a representation.
    private func content(from representation: ClipboardItemRepresentation) -> ClipboardItemContent {
        switch representation.payload {
        case .text(let plain, _, _): return .text(plain)
        case .image(let data):       return .image(data)
        case .file(let urls):        return .file(urls)
        }
    }

    // MARK: - Mutations — Pin (task 17.2)

    /// Flips the `isPinned` flag on the matching item by `id` and persists.
    ///
    /// Ordering is not mutated directly; `filteredItems` recomputes the
    /// pinned-first order on demand.
    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        saveToDisk()
    }

    // MARK: - Mutations — Delete / Clear

    /// Removes a specific item from the history by its ID.
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        ocrIndex.clear(for: item.id)
        saveToDisk()
    }

    /// Removes all items from the history.
    func clearAll() {
        for item in items {
            ocrIndex.clear(for: item.id)
        }
        items.removeAll()
        saveToDisk()
    }

    // MARK: - Cap / Age Enforcement (tasks 17.4, 17.5)

    /// Prunes the history so the count of **non-pinned** items does not
    /// exceed the given cap. Pinned items are never evicted.
    ///
    /// When `cap == .unlimited`, this is a no-op.
    func enforceCap(_ cap: HistoryCap) {
        currentCap = cap

        guard case .finite(let maxCount) = cap else { return }
        guard maxCount >= 0 else { return }

        // Count non-pinned items; no work to do if we're under the cap.
        let nonPinnedCount = items.lazy.filter { !$0.isPinned }.count
        guard nonPinnedCount > maxCount else { return }

        // Identify the indices of the oldest non-pinned items to evict.
        let nonPinnedOldestFirst = items
            .enumerated()
            .filter { !$0.element.isPinned }
            .sorted { $0.element.createdAt < $1.element.createdAt }

        let evictCount = nonPinnedCount - maxCount
        let indicesToRemove = Set(nonPinnedOldestFirst.prefix(evictCount).map(\.offset))

        var removedAny = false
        var rebuilt: [ClipboardItem] = []
        rebuilt.reserveCapacity(items.count - evictCount)
        for (index, item) in items.enumerated() {
            if indicesToRemove.contains(index) {
                ocrIndex.clear(for: item.id)
                removedAny = true
            } else {
                rebuilt.append(item)
            }
        }
        if removedAny {
            items = rebuilt
            saveToDisk()
        }
    }

    /// Removes every non-pinned item whose `createdAt` is older than
    /// `days * 86_400` seconds from `Date()`. Pinned items are untouched.
    func enforceAgeExpiry(days: Int) {
        guard days > 0 else { return }
        let threshold = Date().addingTimeInterval(-Double(days) * 86_400)

        var removedAny = false
        var rebuilt: [ClipboardItem] = []
        rebuilt.reserveCapacity(items.count)
        for item in items {
            if !item.isPinned && item.createdAt < threshold {
                ocrIndex.clear(for: item.id)
                removedAny = true
                continue
            }
            rebuilt.append(item)
        }
        if removedAny {
            items = rebuilt
            saveToDisk()
        }
    }

    // MARK: - OCR (task 17.6)

    /// Records the recognized OCR text for the item with the given id.
    ///
    /// Idempotent: applying the same `(text, id)` tuple more than once is a
    /// no-op after the first application. This is the state relied on by
    /// Property 13 (OCR idempotence).
    func applyOCR(_ text: String, to id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if items[index].ocrText == text {
            // Already applied — no mutation, no disk write.
            return
        }
        items[index].ocrText = text
        ocrIndex.set(text, for: id)
        saveToDisk()
    }

    // MARK: - Re-copy (task 17.7)

    /// Re-copies an item's content to the system clipboard.
    ///
    /// - Parameters:
    ///   - item: The history item to re-copy.
    ///   - writer: An object conforming to `ClipboardWritable` (typically
    ///     `ClipboardMonitor`) so the self-initiated pasteboard change is
    ///     ignored on the next poll.
    ///   - format: When `.rich`, text items additionally write any available
    ///     RTF and HTML variants alongside the plain string. When `.plain`,
    ///     only the plain string is written, even if rich variants exist.
    ///     Defaults to `.rich`.
    func recopy(
        _ item: ClipboardItem,
        writer: ClipboardWritable,
        format: RecopyFormat = .rich
    ) {
        writer.setIgnoreSelfWrite()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
            if format == .rich {
                if let rtf = item.rtfData {
                    pasteboard.setData(rtf, forType: .rtf)
                }
                if let html = item.htmlData {
                    pasteboard.setData(html, forType: .html)
                }
            }
        case .image(let data):
            pasteboard.setData(data, forType: .png)
        case .file(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
    }

    // MARK: - Persistence

    /// Loads the clipboard history from disk via `PersistenceManager`, and
    /// hydrates the OCR index from any persisted `ocrText` values.
    func loadFromDisk() {
        items = PersistenceManager.load()
        for item in items {
            if let text = item.ocrText, !text.isEmpty {
                ocrIndex.set(text, for: item.id)
            }
        }
    }

    /// Saves the current clipboard history to disk via `PersistenceManager`.
    func saveToDisk() {
        do {
            try PersistenceManager.save(items)
        } catch {
            Self.logger.warning(
                "Failed to save clipboard history: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: - NSPasteboard.PasteboardType helpers

private extension NSPasteboard.PasteboardType {
    /// macOS does not ship a stock `NSPasteboard.PasteboardType.html`;
    /// define it here against `public.html` for rich re-copy.
    static let html = NSPasteboard.PasteboardType("public.html")
}
