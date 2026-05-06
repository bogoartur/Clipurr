// OCRService.swift
// Clipurr
//
// On-device optical character recognition over Apple's Vision framework.
// Runs off the main actor (actor-isolated) so the heavy `VNRecognizeTextRequest`
// work never blocks the SwiftUI main actor. Failures are logged via `os_log`
// and surface as an empty string so the calling `HistoryStore` can continue
// operating without stalling the clipboard history (Requirement 9.8).

import Foundation
import Vision
import ImageIO
import CoreGraphics
import os.log

// MARK: - OCRService

/// Actor-isolated service that recognizes text inside image data using the
/// Vision framework's `VNRecognizeTextRequest`.
///
/// The service intentionally owns a mutable `recognitionLanguages` list so a
/// future `PreferencesStore`-driven surface can customize it without forcing
/// the actor to be recreated. The default list covers the eight languages
/// required by Requirement 9.2.
actor OCRService {

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.clipurr.app",
        category: "OCRService"
    )

    // MARK: - State

    /// Languages passed to `VNRecognizeTextRequest.recognitionLanguages`.
    /// Defaults to eight locales covering western European, Japanese, and
    /// simplified Chinese scripts as required by Requirement 9.2.
    var recognitionLanguages: [String] = [
        "en-US",
        "de-DE",
        "fr-FR",
        "es-ES",
        "it-IT",
        "pt-BR",
        "ja-JP",
        "zh-Hans",
    ]

    // MARK: - Init

    init() {}

    // MARK: - Recognition

    /// Recognizes text in the provided image data.
    ///
    /// Decodes the bytes into a `CGImage` via `CGImageSourceCreateWithData`,
    /// runs a single `VNRecognizeTextRequest` with `.accurate` recognition
    /// level and language correction enabled, and returns the top candidate
    /// of each observation joined by newlines.
    ///
    /// Returns the empty string and logs a warning on any failure: decode
    /// failure, a `VNImageRequestHandler.perform` throw, or zero observations.
    /// This matches Requirement 9.8, which requires OCR failures to record an
    /// empty OCR text without blocking the history.
    ///
    /// - Parameter imageData: Raw image bytes in any format understood by
    ///   `CGImageSource` (PNG, TIFF, JPEG, …).
    /// - Returns: The recognized text joined with newlines, or `""` on failure.
    func recognize(imageData: Data) async -> String {
        // Decode bytes → CGImage.
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            Self.logger.warning("OCR decode failed: could not create CGImage from \(imageData.count, privacy: .public) bytes")
            return ""
        }

        // Configure the request.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages
        request.usesLanguageCorrection = true

        // Execute.
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Self.logger.warning("OCR perform failed: \(error.localizedDescription, privacy: .public)")
            return ""
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        if observations.isEmpty {
            Self.logger.debug("OCR produced no observations")
            return ""
        }

        let lines: [String] = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return lines.joined(separator: "\n")
    }
}
