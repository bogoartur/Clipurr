// ClipboardMonitor.swift
// CopyCat
//
// Polls the system clipboard for new text and image content.

import Foundation
import AppKit
import os.log

// MARK: - ClipboardMonitor

/// Monitors `NSPasteboard.general` for new clipboard content by polling
/// `changeCount` on a 0.5-second timer.
///
/// When a change is detected and `ignoreSelfWrite` is `false`, the monitor
/// reads the pasteboard for text or image content and invokes `onNewContent`.
/// When `ignoreSelfWrite` is `true` (set before a re-copy operation), the
/// next detected change resets the flag without creating an item.
@Observable
final class ClipboardMonitor: ClipboardWritable {

    // MARK: - Constants

    /// Maximum image size in bytes (10 MB).
    private static let maxImageSize = 10 * 1024 * 1024

    /// Polling interval in seconds.
    private static let pollingInterval: TimeInterval = 0.5

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "ClipboardMonitor"
    )

    // MARK: - Stored Properties

    /// The timer that drives pasteboard polling.
    private var timer: Timer?

    /// The last observed `NSPasteboard.general.changeCount`.
    private var lastChangeCount: Int

    /// When `true`, the next detected pasteboard change is ignored (self-write).
    private var ignoreSelfWrite: Bool = false

    /// Callback invoked when new clipboard content is detected.
    var onNewContent: ((ClipboardItemContent) -> Void)?

    // MARK: - Initializer

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
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
    ///
    /// Called by `HistoryStore.recopy(_:writer:)` before writing content to
    /// the pasteboard so the monitor does not create a duplicate item.
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

        // Try to read content from the pasteboard.
        if let content = readContent(from: pasteboard) {
            onNewContent?(content)
        }
    }

    /// Attempts to read recognized content from the pasteboard.
    ///
    /// Checks for text first (`.string` type), then image types (`.tiff`,
    /// `.png`). Returns `nil` if no recognized type is found or if the
    /// image exceeds the 10 MB size limit.
    private func readContent(from pasteboard: NSPasteboard) -> ClipboardItemContent? {
        // Check for text content first.
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .text(text)
        }

        // Check for image content (TIFF or PNG).
        if let imageData = readImageData(from: pasteboard) {
            return .image(imageData)
        }

        // No recognized content type.
        return nil
    }

    /// Reads image data from the pasteboard and converts it to PNG.
    ///
    /// Supports `.tiff` and `.png` pasteboard types. TIFF data is converted
    /// to PNG via `NSBitmapImageRep`. Returns `nil` if no image data is
    /// found, conversion fails, or the resulting PNG exceeds 10 MB.
    private func readImageData(from pasteboard: NSPasteboard) -> Data? {
        // Try PNG first (no conversion needed).
        if let pngData = pasteboard.data(forType: .png) {
            if pngData.count > Self.maxImageSize {
                Self.logger.warning("Skipping image: PNG data exceeds 10 MB (\(pngData.count) bytes)")
                return nil
            }
            return pngData
        }

        // Try TIFF and convert to PNG.
        if let tiffData = pasteboard.data(forType: .tiff) {
            guard let imageRep = NSBitmapImageRep(data: tiffData) else {
                Self.logger.warning("Failed to create NSBitmapImageRep from TIFF data")
                return nil
            }

            guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
                Self.logger.warning("Failed to convert NSBitmapImageRep to PNG representation")
                return nil
            }

            if pngData.count > Self.maxImageSize {
                Self.logger.warning("Skipping image: converted PNG data exceeds 10 MB (\(pngData.count) bytes)")
                return nil
            }

            return pngData
        }

        return nil
    }
}
