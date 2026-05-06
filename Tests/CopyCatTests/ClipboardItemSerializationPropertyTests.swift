// ClipboardItemSerializationPropertyTests.swift
// CopyCat
//
// Property-based tests for ClipboardItem JSON serialization.
// Uses SwiftCheck + XCTest because SwiftCheck's `property`/`forAll`
// combinators report failures through XCTFail.

import XCTest
import SwiftCheck
import Foundation
@testable import CopyCat

// MARK: - Arbitrary conformances

extension ClipboardItemContent: Arbitrary {
    /// Generates either an arbitrary UTF-8 text payload or an arbitrary
    /// byte sequence wrapped in `Data` to represent image content.
    public static var arbitrary: Gen<ClipboardItemContent> {
        return Gen<ClipboardItemContent>.one(of: [
            String.arbitrary.map(ClipboardItemContent.text),
            [UInt8].arbitrary.map { bytes in .image(Data(bytes)) }
        ])
    }
}

extension ClipboardItem: Arbitrary {
    /// Generates a `ClipboardItem` with a fresh UUID, arbitrary content,
    /// and a `createdAt` date at integer-second resolution.
    ///
    /// The second-resolution date is intentional: `JSONEncoder`'s default
    /// `.iso8601` strategy uses `ISO8601DateFormatter` without fractional
    /// seconds, so any sub-second precision in the source date would be
    /// dropped on encode and the round-trip equality check would fail for
    /// reasons unrelated to the property being validated.
    public static var arbitrary: Gen<ClipboardItem> {
        return ClipboardItemContent.arbitrary.flatMap { content in
            // Range: 1970-01-01 through ~2100-01-01 in whole seconds.
            Gen<Int>.choose((0, 4_102_444_800)).map { timestamp in
                ClipboardItem(
                    id: UUID(),
                    content: content,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(timestamp))
                )
            }
        }
    }
}

// MARK: - Property 8: Serialization round-trip
// **Validates: Requirements 6.5, 6.6**

final class ClipboardItemSerializationPropertyTests: XCTestCase {

    /// Property 8: For any valid `ClipboardItem` — text with arbitrary UTF-8
    /// strings, or image with arbitrary byte data — encoding it to JSON and
    /// decoding it back produces a `ClipboardItem` equal to the original.
    ///
    /// Uses SwiftCheck's default `maxAllowableSuccessfulTests` of 100.
    ///
    /// **Validates: Requirements 6.5, 6.6**
    func testSerializationRoundTripProperty() {
        property("ClipboardItem round-trips through JSON encoding")
            <- forAll { (item: ClipboardItem) in
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                do {
                    let encoded = try encoder.encode(item)
                    let decoded = try decoder.decode(ClipboardItem.self, from: encoded)
                    return decoded == item
                } catch {
                    return false
                }
            }
    }
}
