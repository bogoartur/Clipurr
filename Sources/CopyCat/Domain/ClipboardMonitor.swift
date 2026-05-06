// ClipboardMonitor.swift
// CopyCat
//
// Polls the system clipboard for new content. Extraction is delegated to
// `ContentTypeExtractor` (task 14) and image items fire an async OCR job
// via `OCRService` (task 13), with the recognized text routed back to
// `HistoryStore.applyOCR(_:to:)` on the main actor.

import Foundation
import AppKit
import os.log

// MARK: - ClipboardMonitor

/// Monitors `NSPasteboard.general` for new clipboard content by polling
/// `changeCount` on a 0.5-second timer.
///
/// When a change is detected and `ignoreSelfWrite` is `false`, the monitor
/// uses `ContentTypeExtractor.extract(from:)` to obtain the richest
/// representation and invokes `onNewContent(_:)` synchronously. For image
/// representations, the monitor additionally kicks off an asynchronous
/// `OCRService.recognize(imageData:)` task and invokes `onOCRCompleted`
/// with the resulting `(id, text)` tuple once recognition finishes.
@Observable
final class ClipboardMonitor: ClipboardWritable {

    // MARK: - Constants

    /// Polling interval in seconds.
    private static let pollingInterval: TimeInterval = 0.5

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "ClipboardMonitor"
    )

    // MARK: - Dependencies

    /// Extractor that reads the pasteboard and produces a representation.
    @ObservationIgnored
    private let extractor: ContentTypeExtractor.Type

    /// Async text recognizer used for image items. Optional so older wiring
    /// that does not care about OCR can pass `nil`.
    @ObservationIgnored
    private let ocrService: OCRService?

    // MARK: - Stored Properties

    /// The timer that drives pasteboard polling.
    private var timer: Timer?

    /// The last observed `NSPasteboard.general.changeCount`.
    private var lastChangeCount: Int

    /// When `true`, the next detected pasteboard change is ignored (self-write).
    private var ignoreSelfWrite: Bool = false

    /// Callback invoked when new clipboard content is detected. The caller
    /// should return the `UUID` of the `ClipboardItem` that was created or
    /// promoted so the monitor can target any follow-up OCR update to the
    /// correct row. `nil` means the representation was absorbed silently
    /// (e.g. matched an existing pinned item with no other changes).
    var onNewContent: ((ClipboardItemRepresentation) -> UUID?)?

    /// Callback invoked when OCR completes for a previously-reported image
    /// item. Fires on the main actor.
    var onOCRCompleted: ((UUID, String) -> Void)?

    // MARK: - Initializer

    /// - Parameters:
    ///   - extractor: Content-type extractor. Defaults to the shared
    ///     `ContentTypeExtractor` enum; tests may inject a stub.
    ///   - ocrService: Optional OCR service. When `nil`, image items are
    ///     stored without recognized text.
    init(
        extractor: ContentTypeExtractor.Type = ContentTypeExtractor.self,
        ocrService: OCRService? = nil
    ) {
        self.extractor = extractor
        self.ocrService = ocrService
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Public Methods

    /// Begins polling the system pasteboard for changes.
    ///
    /// Creates a repeating timer on the current run loop that fires every
    /// 0.5 seconds. If monitoring is already active, this method is a no-op.
    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    /// Stops polling the system pasteboard.
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Signals the monitor to ignore the next detected pasteboard change.
    func setIgnoreSelfWrite() {
        ignoreSelfWrite = true
    }

    // MARK: - Private Methods

    /// Checks `NSPasteboard.general.changeCount` and processes new content.
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // If this change was initiated by a re-copy, skip it.
        if ignoreSelfWrite {
            ignoreSelfWrite = false
            return
        }

        // Use the extractor to obtain the richest available representation.
        guard let representation = extractor.extract(from: pasteboard) else { return }

        // Hand off to the store and capture the item id so OCR can target it.
        let id = onNewContent?(representation)

        // Fire async OCR for image payloads when an OCR service is available
        // and the store reported a target id.
        if case .image(let data) = representation.payload,
           let id,
           let ocrService {
            Task.detached { [weak self] in
                let text = await ocrService.recognize(imageData: data)
                await MainActor.run {
                    self?.onOCRCompleted?(id, text)
                }
            }
        }
    }
}
