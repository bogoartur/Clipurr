// StatusBarController.swift
// CopyCat
//
// Manages the NSStatusItem and NSPopover for the menu bar presence.
// The status item uses a clipboard SF Symbol and the popover is configured
// with transient behavior for auto-dismiss on outside click. On show, the
// controller asks its injected `AutoPasteService` to snapshot the previous
// frontmost app so quick-paste can later restore focus.

import AppKit
import SwiftUI

@MainActor
final class StatusBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem
    private var popover: NSPopover

    /// Optional auto-paste coordinator. When injected, `showPopover()` calls
    /// `capturePreviousFrontmostApp()` so Cmd+1..Cmd+9 quick-paste can
    /// restore focus to that app after re-copy. When `nil`, quick-paste
    /// still works, but auto-paste is a no-op.
    private let autoPasteService: AutoPasteService?

    /// The popover behavior set during `configurePopover()`, used to restore
    /// the default after a drag-originating-from-the-popover completes
    /// (task 21.5 will flip to `.applicationDefined` during drags).
    @ObservationIgnored
    private let defaultPopoverBehavior: NSPopover.Behavior = .transient

    // MARK: - Initialization

    /// - Parameter autoPasteService: Injected for quick-paste focus handoff.
    ///   Pass `nil` when not needed (e.g. in unit tests).
    init(autoPasteService: AutoPasteService? = nil) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        self.autoPasteService = autoPasteService

        configureStatusItem()
        configurePopover()
    }

    // MARK: - Setup

    /// Configures the popover content with the given SwiftUI view.
    func setup(with contentView: some View) {
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
    }

    // MARK: - Popover Control

    /// Toggles the popover visibility. Shows it if hidden, dismisses it if shown.
    func togglePopover() {
        if popover.isShown {
            dismissPopover()
        } else {
            showPopover()
        }
    }

    /// Shows the popover anchored to the status item button.
    ///
    /// Snapshots the previously-frontmost app via `autoPasteService` before
    /// the popover takes focus so quick-paste has a target to restore.
    func showPopover() {
        guard let button = statusItem.button else { return }

        // Capture BEFORE the popover takes focus — otherwise we'd observe
        // CopyCat as frontmost and have nowhere to paste into.
        autoPasteService?.capturePreviousFrontmostApp()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Ensure the popover window becomes key so it can receive keyboard events
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Dismisses the popover if it is currently shown.
    func dismissPopover() {
        popover.performClose(nil)
    }

    /// Temporarily overrides the popover behavior (used during in-flight
    /// drags by task 21.5 so the popover doesn't auto-dismiss mid-drag).
    func setPopoverBehavior(_ behavior: NSPopover.Behavior) {
        popover.behavior = behavior
    }

    /// Restores the popover's default transient behavior.
    func restoreDefaultPopoverBehavior() {
        popover.behavior = defaultPopoverBehavior
    }

    // MARK: - Private Configuration

    private func configureStatusItem() {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyCat Clipboard Manager")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = defaultPopoverBehavior
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: Any?) {
        togglePopover()
    }
}
