import Testing
import AppKit
@testable import Clipurr

@MainActor
@Suite("Workflow boundaries", .serialized)
struct WorkflowTests {
    @Test("named pasteboard extraction and rich recopy preserve formats")
    func richRecopy() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let rtf = Data("{\\rtf1 sample}".utf8)
        board.setString("sample", forType: .string)
        board.setData(rtf, forType: .rtf)
        let representation = try #require(ContentTypeExtractor.extract(from: board))
        let store = HistoryStore()
        store.addRepresentation(representation)
        let item = try #require(store.items.first)
        store.recopy(item, writer: MockClipboardWriter(), format: .rich, pasteboard: board)
        #expect(board.string(forType: .string) == "sample")
        #expect(board.data(forType: .rtf) == rtf)
        store.recopy(item, writer: MockClipboardWriter(), format: .plain, pasteboard: board)
        #expect(board.string(forType: .string) == "sample")
        #expect(board.data(forType: .rtf) == nil)
    }

    @Test("pins survive cap eviction and duplicate capture")
    func pinRetention() throws {
        let store = HistoryStore()
        store.addItem(.text("keep"))
        store.togglePin(try #require(store.items.first))
        store.enforceCap(.finite(1))
        store.addItem(.text("old"))
        store.addItem(.text("new"))
        store.addItem(.text("keep"))
        #expect(store.items.count == 2)
        #expect(store.filteredItems.first?.content == .text("keep"))
        #expect(store.items.contains { $0.content == .text("new") })
        #expect(!store.items.contains { $0.content == .text("old") })
    }

    @Test("Vision recognizes the demo image and makes it searchable")
    func imageOCRSearch() async throws {
        let data = DemoSamples.notesImage()
        let text = await OCRService().recognize(imageData: data)
        #expect(text.localizedCaseInsensitiveContains("React"))
        let store = HistoryStore()
        let id = try #require(store.addRepresentation(.init(payload: .image(data))))
        store.applyOCR(text, to: id)
        store.searchQuery = "react"
        #expect(store.filteredItems.count == 1)
        #expect(store.filteredItems.first?.id == id)
    }

    @Test("invalid images fail OCR without producing text")
    func invalidImage() async {
        let text = await OCRService().recognize(imageData: Data([1, 2, 3]))
        #expect(text.isEmpty)
    }
}
