// AppDelegate.swift
// CopyCat
//
// Application delegate that bootstraps all core services on launch.
// Sets the app to accessory mode (no Dock icon), creates the status bar
// controller, clipboard monitor, history store, and keyboard shortcut
// manager, then wires them together.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// Controls the menu bar status item and popover.
    private(set) var statusBarController: StatusBarController!

    /// Stores and manages the clipboard history.
    private(set) var historyStore: HistoryStore!

    /// Polls the system clipboard for new content.
    private(set) var clipboardMonitor: ClipboardMonitor!

    /// Registers the global Cmd+Shift+V keyboard shortcut.
    private(set) var keyboardShortcutManager: KeyboardShortcutManager!

    /// Manages the launch-at-login preference.
    private(set) var launchAtLoginManager: LaunchAtLoginManager!

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu bar-only app (no Dock icon).
        NSApp.setActivationPolicy(.accessory)

        // Create core components.
        historyStore = HistoryStore()
        clipboardMonitor = ClipboardMonitor()
        statusBarController = StatusBarController()
        keyboardShortcutManager = KeyboardShortcutManager()
        launchAtLoginManager = LaunchAtLoginManager()

        // Restore persisted clipboard history from disk.
        historyStore.loadFromDisk()

        // Wire clipboard monitor to history store: new content is added to history.
        clipboardMonitor.onNewContent = { [weak self] content in
            self?.historyStore.addItem(content)
        }

        // Start polling the system clipboard.
        clipboardMonitor.startMonitoring()

        // Create the popover content view with shared dependencies.
        let popoverView = PopoverView(
            store: historyStore,
            monitor: clipboardMonitor,
            onDismiss: { [weak self] in
                self?.statusBarController.dismissPopover()
            }
        )
        statusBarController.setup(with: popoverView)

        // Register the global keyboard shortcut to toggle the popover.
        keyboardShortcutManager.register { [weak self] in
            self?.statusBarController.togglePopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stopMonitoring()
        keyboardShortcutManager.unregister()
    }
}
