// StatusBarController.swift
// CopyCat
//
// Manages the NSStatusItem and NSPopover for the menu bar presence.
// The status item uses a clipboard SF Symbol and the popover is configured
// with transient behavior for auto-dismiss on outside click.

import AppKit
import SwiftUI

@MainActor
final class StatusBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem
    private var popover: NSPopover

    // MARK: - Initialization

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()

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
    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Ensure the popover window becomes key so it can receive keyboard events
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Dismisses the popover if it is currently shown.
    func dismissPopover() {
        popover.performClose(nil)
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
        popover.behavior = .transient
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: Any?) {
        togglePopover()
    }
}
