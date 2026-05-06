// PersistenceManager.swift
// Clipurr
//
// Handles encoding/decoding [ClipboardItem] to/from a JSON file
// in the app's Application Support directory.

import Foundation
import os.log

/// Manages persistence of clipboard history to a JSON file on disk.
///
/// The history is stored at `~/Library/Application Support/Clipurr/history.json`.
/// Writes are performed atomically (write to a temporary file, then rename) to
/// prevent corruption if the app is terminated mid-write.
struct PersistenceManager {

    // MARK: - File Location

    /// The directory where Clipurr stores its data.
    static let directoryURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Clipurr", isDirectory: true)
    }()

    /// The URL of the history JSON file.
    static let fileURL: URL = {
        directoryURL.appendingPathComponent("history.json")
    }()

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.clipurr.app",
        category: "PersistenceManager"
    )

    // MARK: - Encoder / Decoder

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Public API

    /// Saves the given clipboard items to disk as JSON.
    ///
    /// Creates the Application Support subdirectory if it doesn't exist.
    /// Writes atomically by first writing to a temporary file, then renaming
    /// it to the final path to prevent corruption on termination.
    ///
    /// - Parameter items: The clipboard items to persist.
    /// - Throws: An error if encoding or file system operations fail.
    static func save(_ items: [ClipboardItem]) throws {
        let fileManager = FileManager.default

        // Ensure the directory exists
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode items to JSON data
        let data = try encoder.encode(items)

        // Write atomically: write to a temp file, then rename
        let tempURL = directoryURL.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL, options: [.atomic])

        // Replace the existing file with the temp file
        // If the destination already exists, remove it first
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }
    }

    /// Loads clipboard items from the JSON file on disk.
    ///
    /// If the file does not exist, returns an empty array. If the file exists
    /// but cannot be decoded (corrupted data), logs a warning and returns an
    /// empty array rather than throwing.
    ///
    /// - Returns: The persisted clipboard items, or an empty array on failure.
    static func load() -> [ClipboardItem] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items
        } catch {
            logger.warning(
                "Failed to decode clipboard history from \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public). Returning empty history."
            )
            return []
        }
    }
}
