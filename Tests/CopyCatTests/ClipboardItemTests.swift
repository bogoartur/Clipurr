import Testing
import Foundation
@testable import CopyCat

@Suite("ClipboardItemContent")
struct ClipboardItemContentTests {

    @Test("Text content round-trips through JSON")
    func textCodableRoundTrip() throws {
        let original = ClipboardItemContent.text("Hello, world!")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItemContent.self, from: data)
        #expect(decoded == original)
    }

    @Test("Image content round-trips through JSON")
    func imageCodableRoundTrip() throws {
        let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let original = ClipboardItemContent.image(pngBytes)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItemContent.self, from: data)
        #expect(decoded == original)
    }

    @Test("Text JSON has expected shape")
    func textJsonShape() throws {
        let content = ClipboardItemContent.text("test")
        let data = try JSONEncoder().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["text"] as? String == "test")
        #expect(json?["image"] == nil)
    }

    @Test("Image JSON has expected shape")
    func imageJsonShape() throws {
        let content = ClipboardItemContent.image(Data([0xFF]))
        let data = try JSONEncoder().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["image"] != nil)
        #expect(json?["text"] == nil)
    }

    @Test("Decoding invalid JSON throws")
    func decodingInvalidJsonThrows() throws {
        let badJson = Data("{}".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ClipboardItemContent.self, from: badJson)
        }
    }

    @Test("Equatable distinguishes text from image")
    func equatableDistinguishesCases() {
        let text = ClipboardItemContent.text("abc")
        let image = ClipboardItemContent.image(Data("abc".utf8))
        #expect(text != image)
    }
}

@Suite("ClipboardItem")
struct ClipboardItemTests {

    @Test("Full item round-trips through JSON with iso8601 dates")
    func fullItemRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = ClipboardItem(
            id: UUID(),
            content: .text("Round-trip test"),
            createdAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipboardItem.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - textPreview

    @Test("textPreview returns short text unchanged")
    func textPreviewShortText() {
        let item = ClipboardItem(
            id: UUID(),
            content: .text("Short"),
            createdAt: Date()
        )
        #expect(item.textPreview == "Short")
    }

    @Test("textPreview returns exactly 80-char text unchanged")
    func textPreviewExactly80() {
        let text = String(repeating: "a", count: 80)
        let item = ClipboardItem(
            id: UUID(),
            content: .text(text),
            createdAt: Date()
        )
        #expect(item.textPreview == text)
        #expect(item.textPreview.count == 80)
    }

    @Test("textPreview truncates 81-char text to 80 with ellipsis")
    func textPreviewTruncates81() {
        let text = String(repeating: "b", count: 81)
        let item = ClipboardItem(
            id: UUID(),
            content: .text(text),
            createdAt: Date()
        )
        #expect(item.textPreview.count == 80)
        #expect(item.textPreview.hasSuffix("…"))
        #expect(item.textPreview == String(repeating: "b", count: 79) + "…")
    }

    @Test("textPreview truncates long text to 80 with ellipsis")
    func textPreviewTruncatesLong() {
        let text = String(repeating: "x", count: 200)
        let item = ClipboardItem(
            id: UUID(),
            content: .text(text),
            createdAt: Date()
        )
        #expect(item.textPreview.count == 80)
        #expect(item.textPreview.hasSuffix("…"))
    }

    @Test("textPreview returns [Image] for image content")
    func textPreviewImage() {
        let item = ClipboardItem(
            id: UUID(),
            content: .image(Data([0x00])),
            createdAt: Date()
        )
        #expect(item.textPreview == "[Image]")
    }

    @Test("textPreview handles empty string")
    func textPreviewEmptyString() {
        let item = ClipboardItem(
            id: UUID(),
            content: .text(""),
            createdAt: Date()
        )
        #expect(item.textPreview == "")
    }
}
