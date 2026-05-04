// HistoryStore.swift
// CopyCat
//
// Manages the in-memory clipboard history and coordinates persistence.

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
/// Holds an ordered list of `ClipboardItem` values (newest first), provides
/// add / delete / clear / re-copy mutations, search filtering, and delegates
/// persistence to `PersistenceManager`.
@Observable
final class HistoryStore {

    // MARK: - Constants

    /// Maximum number of items retained in history.
    static let maxItems = 50

    // MARK: - Stored Properties

    /// The full clipboard history, ordered newest-first.
    private(set) var items: [ClipboardItem] = []

    /// The current search filter text entered by the user.
    var searchQuery: String = ""

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "HistoryStore"
    )

    // MARK: - Computed Properties

    /// Items matching the current search query.
    ///
    /// When `searchQuery` is non-empty, returns only text items whose content
    /// contains the query case-insensitively. Image items are excluded from
    /// search results. When `searchQuery` is empty, returns all items.
    var filteredItems: [ClipboardItem] {
        guard !searchQuery.isEmpty else {
            return items
        }
        return items.filter { item in
            switch item.content {
            case .text(let text):
                return text.localizedCaseInsensitiveContains(searchQuery)
            case .image:
                return false
            }
        }
    }

    /// The number of items matching the current search filter.
    var matchCount: Int {
        filteredItems.count
    }

    // MARK: - Mutations

    /// Adds new clipboard content to the history.
    ///
    /// - Checks for duplicate against the most recent item; discards if identical.
    /// - Prepends the new item so the list stays newest-first.
    /// - Enforces the 50-item cap by removing the oldest item(s).
    /// - Persists the updated history to disk.
    ///
    /// - Parameter content: The clipboard content to add.
    func addItem(_ content: ClipboardItemContent) {
        // Duplicate check: skip if identical to the most recent item
        if let mostRecent = items.first, mostRecent.content == content {
            return
        }

        let newItem = ClipboardItem(
            id: UUID(),
            content: content,
            createdAt: Date()
        )

        items.insert(newItem, at: 0)

        // Enforce the history cap
        if items.count > Self.maxItems {
            items = Array(items.prefix(Self.maxItems))
        }

        saveToDisk()
    }

    /// Removes a specific item from the history by its ID.
    ///
    /// - Parameter item: The item to delete.
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    /// Removes all items from the history.
    func clearAll() {
        items.removeAll()
        saveToDisk()
    }

    /// Re-copies an item's content to the system clipboard.
    ///
    /// Signals the clipboard monitor to ignore the self-initiated pasteboard
    /// change, then writes the item's content to `NSPasteboard.general`.
    ///
    /// - Parameters:
    ///   - item: The history item to re-copy.
    ///   - writer: An object conforming to `ClipboardWritable` (typically `ClipboardMonitor`).
    func recopy(_ item: ClipboardItem, writer: ClipboardWritable) {
        writer.setIgnoreSelfWrite()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .png)
        }
    }

    // MARK: - Persistence

    /// Loads the clipboard history from disk via `PersistenceManager`.
    func loadFromDisk() {
        items = PersistenceManager.load()
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
