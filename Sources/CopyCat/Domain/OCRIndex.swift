// OCRIndex.swift
// CopyCat
//
// In-memory `[ClipboardItem.id: OCR text]` cache. Written alongside the
// persisted `ClipboardItem.ocrText` field so the hot path of filtering
// by search query can consult a dictionary rather than scanning the full
// history array. `HistoryStore` owns the single instance and keeps it
// in sync via `applyOCR(_:to:)` (task 17.6).

import Foundation

/// A lightweight observable cache of OCR text keyed by `ClipboardItem.id`.
///
/// This is a pure in-memory index; persistence lives on `ClipboardItem.ocrText`.
/// `HistoryStore` hydrates the index from persisted items on load and keeps
/// it synchronized when new OCR results arrive.
@Observable
@MainActor
final class OCRIndex {

    /// The id → recognized text mapping. Writes go through `set(_:for:)`
    /// and `clear(for:)` so observers see a single mutation per operation.
    private(set) var texts: [UUID: String] = [:]

    /// Records the recognized text for the item with the given id.
    ///
    /// Writing the same `(text, id)` tuple a second time is a no-op (the
    /// underlying dictionary write is idempotent), which is the state
    /// `HistoryStore.applyOCR(_:to:)` relies on for Property 13.
    func set(_ text: String, for id: UUID) {
        texts[id] = text
    }

    /// Drops the entry for the given id, if present.
    func clear(for id: UUID) {
        texts.removeValue(forKey: id)
    }
}
