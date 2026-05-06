// AutoPasteService.swift
// Clipurr
//
// Optional quick-paste side channel. After a Cmd+1..Cmd+9 re-copy, this
// service reactivates the app that was frontmost before the popover took
// focus and synthesizes a Cmd+V key event so the user gets the pasted
// content in the previous app without manually pressing paste.
//
// The synthetic paste requires Accessibility permission. When permission
// is missing we still complete the re-copy (the clipboard is updated)
// but skip the synthetic Cmd+V and surface a one-per-session signal so
// the UI can show a banner.

import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os.log

// MARK: - AutoPasteService

/// Captures the previously-frontmost app on popover show and, when auto-paste
/// is enabled, reactivates that app and synthesizes Cmd+V to paste the
/// freshly-recopied content.
@MainActor
final class AutoPasteService {

    // MARK: - Logger

    private let logger = Logger(
        subsystem: "com.clipurr.app",
        category: "AutoPasteService"
    )

    // MARK: - State

    /// The app that was frontmost when the popover was shown. `nil` when the
    /// popover hasn't been shown yet, or when the frontmost app at show-time
    /// was Clipurr itself (we filter those out to avoid pasting into our
    /// own popover).
    private var previousApp: NSRunningApplication?

    /// Whether the "Accessibility denied" banner has already been surfaced
    /// in this app session. Reset on app launch.
    private(set) var didReportAccessibilityDenied: Bool = false

    /// Optional callback invoked the first time Accessibility is denied in a
    /// session so the UI can show a one-time banner / alert. AppDelegate
    /// wires this to a user-facing notification in task 22.1.
    var onAccessibilityDenied: (() -> Void)?

    // MARK: - Capture

    /// Snapshots `NSWorkspace.shared.frontmostApplication` so a subsequent
    /// `pasteIntoPreviousApp()` knows where to send the synthetic Cmd+V.
    /// Called by `StatusBarController.showPopover()` **before** the popover
    /// becomes key.
    func capturePreviousFrontmostApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        // Ignore self so we don't try to paste into our own popover when
        // the user opens Clipurr from the menu bar (the popover inherits
        // frontmost-app focus very briefly).
        if frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        previousApp = frontmost
    }

    // MARK: - Paste

    /// Activates the captured previous app and synthesizes a Cmd+V key event.
    ///
    /// Early-returns when no previous app is captured. When `AXIsProcessTrusted()`
    /// is `false`, prompts once via `promptForAccessibilityIfNeeded()`, fires
    /// the one-per-session denial callback, and returns without synthesizing
    /// the key event.
    func pasteIntoPreviousApp() {
        guard let previousApp else {
            logger.debug("Auto-paste skipped: no previous frontmost app captured")
            return
        }

        // Accessibility gate. Without this permission `CGEvent.post` is a no-op
        // from a sandboxed or untrusted process, so we prompt once and bail out.
        guard AXIsProcessTrusted() else {
            _ = promptForAccessibilityIfNeeded()
            if !didReportAccessibilityDenied {
                didReportAccessibilityDenied = true
                onAccessibilityDenied?()
            }
            logger.warning("Auto-paste skipped: Accessibility permission not granted")
            return
        }

        // Reactivate the captured app. `.activate(options: [])` is the macOS 14+
        // API; older flags (`.activateIgnoringOtherApps`) are deprecated but
        // still accepted, so a plain `.activate()` is enough.
        previousApp.activate(options: [])

        // Give the activation a moment to settle before posting the synthetic
        // key event. 50 ms is enough for frontmost-app changes to propagate
        // without being user-visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [logger] in
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey = CGKeyCode(kVK_ANSI_V)

            guard
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
                let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            else {
                logger.warning("Auto-paste skipped: CGEvent creation failed")
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Permission

    /// Returns whether the process is trusted for Accessibility. When
    /// untrusted, `AXIsProcessTrustedWithOptions` surfaces the system prompt
    /// so the user can grant permission without leaving their workflow.
    @discardableResult
    func promptForAccessibilityIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
