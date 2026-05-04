import Testing
import Foundation
@testable import CopyCat

// MARK: - Mock ClipboardWritable

/// A test double that records whether `setIgnoreSelfWrite()` was called.
final class MockClipboardWriter: ClipboardWritable {
    var ignoreSelfWriteCalled = false

    func setIgnoreSelfWrite() {
        ignoreSelfWriteCalled = true
    }
}

// MARK: - Helpers

/// Creates a `ClipboardItem` with the given text content and optional date.
private func textItem(_ text: String, date: Date = Date()) -> ClipboardItem {
    ClipboardItem(id: UUID(), content: .text(text), createdAt: date)
}

/// Creates a `ClipboardItem` with the given image data and optional date.
private func imageItem(_ data: Data = Data([0x89, 0x50, 0x4E, 0x47]), date: Date = Date()) -> ClipboardItem {
    ClipboardItem(id: UUID(), content: .image(data), createdAt: date)
}

// MARK: - Tests

@Suite("HistoryStore — addItem")
struct HistoryStoreAddItemTests {

    @Test("addItem prepends new text item at index 0")
    func addItemPrependsText() {
        let store = HistoryStore()
        store.addItem(.text("Hello"))
        #expect(store.items.count == 1)
        #expect(store.items[0].content == .text("Hello"))
    }

    @Test("addItem prepends new image item at index 0")
    func addItemPrependsImage() {
        let store = HistoryStore()
        let data = Data([0x89, 0x50])
        store.addItem(.image(data))
        #expect(store.items.count == 1)
        #expect(store.items[0].content == .image(data))
    }

    @Test("addItem discards duplicate of most recent item")
    func addItemDiscardsDuplicate() {
        let store = HistoryStore()
        store.addItem(.text("Same"))
        store.addItem(.text("Same"))
        #expect(store.items.count == 1)
    }

    @Test("addItem allows non-duplicate even if content exists elsewhere in history")
    func addItemAllowsNonRecentDuplicate() {
        let store = HistoryStore()
        store.addItem(.text("First"))
        store.addItem(.text("Second"))
        store.addItem(.text("First")) // Not a duplicate of most recent ("Second")
        #expect(store.items.count == 3)
        #expect(store.items[0].content == .text("First"))
    }

    @Test("addItem enforces 50-item cap by removing oldest")
    func addItemEnforcesCap() {
        let store = HistoryStore()
        // Fill to capacity
        for i in 0..<50 {
            store.addItem(.text("Item \(i)"))
        }
        #expect(store.items.count == 50)

        // Adding one more should evict the oldest
        store.addItem(.text("Item 50"))
        #expect(store.items.count == 50)
        #expect(store.items[0].content == .text("Item 50"))
        // The oldest item ("Item 0") should be gone
        let hasItem0 = store.items.contains { $0.content == .text("Item 0") }
        #expect(!hasItem0)
    }

    @Test("addItem with empty history works correctly")
    func addItemEmptyHistory() {
        let store = HistoryStore()
        #expect(store.items.isEmpty)
        store.addItem(.text("First"))
        #expect(store.items.count == 1)
    }
}

@Suite("HistoryStore — deleteItem")
struct HistoryStoreDeleteItemTests {

    @Test("deleteItem removes the specified item by ID")
    func deleteItemRemovesById() {
        let store = HistoryStore()
        store.addItem(.text("Keep"))
        store.addItem(.text("Delete me"))

        let toDelete = store.items[0] // "Delete me" is at index 0
        store.deleteItem(toDelete)

        #expect(store.items.count == 1)
        #expect(store.items[0].content == .text("Keep"))
    }

    @Test("deleteItem on non-existent item does nothing")
    func deleteItemNonExistent() {
        let store = HistoryStore()
        store.addItem(.text("Only"))
        let phantom = ClipboardItem(id: UUID(), content: .text("Ghost"), createdAt: Date())
        store.deleteItem(phantom)
        #expect(store.items.count == 1)
    }
}

@Suite("HistoryStore — clearAll")
struct HistoryStoreClearAllTests {

    @Test("clearAll empties the history")
    func clearAllEmptiesHistory() {
        let store = HistoryStore()
        store.addItem(.text("A"))
        store.addItem(.text("B"))
        store.addItem(.text("C"))
        #expect(store.items.count == 3)

        store.clearAll()
        #expect(store.items.isEmpty)
    }

    @Test("clearAll on empty history is a no-op")
    func clearAllEmptyHistory() {
        let store = HistoryStore()
        store.clearAll()
        #expect(store.items.isEmpty)
    }
}

@Suite("HistoryStore — recopy")
struct HistoryStoreRecopyTests {

    @Test("recopy does not change the history")
    func recopyPreservesHistory() {
        let store = HistoryStore()
        store.addItem(.text("Item A"))
        store.addItem(.text("Item B"))

        let itemsBefore = store.items
        let writer = MockClipboardWriter()
        store.recopy(store.items[1], writer: writer)

        #expect(store.items == itemsBefore)
    }

    @Test("recopy calls setIgnoreSelfWrite on the writer")
    func recopySetsIgnoreFlag() {
        let store = HistoryStore()
        store.addItem(.text("Test"))

        let writer = MockClipboardWriter()
        store.recopy(store.items[0], writer: writer)

        #expect(writer.ignoreSelfWriteCalled)
    }
}

@Suite("HistoryStore — filteredItems & matchCount")
struct HistoryStoreFilterTests {

    @Test("filteredItems returns all items when searchQuery is empty")
    func filteredItemsNoQuery() {
        let store = HistoryStore()
        store.addItem(.text("Apple"))
        store.addItem(.image(Data([0x01])))
        store.addItem(.text("Banana"))

        #expect(store.filteredItems.count == 3)
        #expect(store.matchCount == 3)
    }

    @Test("filteredItems filters text items case-insensitively")
    func filteredItemsCaseInsensitive() {
        let store = HistoryStore()
        store.addItem(.text("Hello World"))
        store.addItem(.text("hello there"))
        store.addItem(.text("Goodbye"))

        store.searchQuery = "hello"
        #expect(store.filteredItems.count == 2)
        #expect(store.matchCount == 2)
    }

    @Test("filteredItems excludes image items when searching")
    func filteredItemsExcludesImages() {
        let store = HistoryStore()
        store.addItem(.text("Photo description"))
        store.addItem(.image(Data([0x89, 0x50])))

        store.searchQuery = "photo"
        #expect(store.filteredItems.count == 1)
        #expect(store.filteredItems[0].content == .text("Photo description"))
    }

    @Test("filteredItems returns empty when no matches")
    func filteredItemsNoMatches() {
        let store = HistoryStore()
        store.addItem(.text("Apple"))
        store.addItem(.text("Banana"))

        store.searchQuery = "Cherry"
        #expect(store.filteredItems.isEmpty)
        #expect(store.matchCount == 0)
    }

    @Test("clearing searchQuery restores all items")
    func clearingQueryRestoresAll() {
        let store = HistoryStore()
        store.addItem(.text("Apple"))
        store.addItem(.text("Banana"))

        store.searchQuery = "Apple"
        #expect(store.filteredItems.count == 1)

        store.searchQuery = ""
        #expect(store.filteredItems.count == 2)
    }
}

@Suite("HistoryStore — maxItems constant")
struct HistoryStoreConstantsTests {

    @Test("maxItems is 50")
    func maxItemsIs50() {
        #expect(HistoryStore.maxItems == 50)
    }
}
