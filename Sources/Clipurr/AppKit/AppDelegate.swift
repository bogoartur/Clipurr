// AppDelegate.swift
// Clipurr
//
// Application delegate that bootstraps all core services on launch.
// Sets the app to accessory mode (no Dock icon), creates the status bar
// controller, clipboard monitor, history store, and preferences, then
// wires them together. The global shortcut is provided by the
// `KeyboardShortcuts` package (Sindre Sorhus) so users can rebind it at
// runtime from the Preferences view (task 22.1).

import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// Controls the menu bar status item and popover.
    private(set) var statusBarController: StatusBarController!

    /// Stores and manages the clipboard history.
    private(set) var historyStore: HistoryStore!

    /// Polls the system clipboard for new content.
    private(set) var clipboardMonitor: ClipboardMonitor!

    /// Manages the launch-at-login preference.
    private(set) var launchAtLoginManager: LaunchAtLoginManager!

    /// On-device OCR service used by the clipboard monitor for image items.
    private(set) var ocrService: OCRService!

    /// Observable store holding the user-tunable preferences.
    @MainActor
    private(set) var preferencesStore: PreferencesStore!

    /// Synthesizes paste into the previously-frontmost app after a quick-paste.
    @MainActor
    private(set) var autoPasteService: AutoPasteService!

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu bar-only app (no Dock icon).
        NSApp.setActivationPolicy(.accessory)

        // Create core components.
        ocrService = OCRService()
        MainActor.assumeIsolated {
            preferencesStore = PreferencesStore()
            autoPasteService = AutoPasteService()
        }
        historyStore = HistoryStore()
        clipboardMonitor = ClipboardMonitor(ocrService: ocrService)
        statusBarController = StatusBarController(autoPasteService: autoPasteService)
        launchAtLoginManager = LaunchAtLoginManager()

        // Restore persisted clipboard history from disk.
        historyStore.loadFromDisk()

        // Apply the persisted history cap before the monitor starts producing
        // new items, so eviction policy is correct from the first save.
        MainActor.assumeIsolated {
            historyStore.enforceCap(preferencesStore.historyCap)
            if let days = preferencesStore.ageExpiryDays {
                historyStore.enforceAgeExpiry(days: days)
            }

            // Observe preference changes so cap/expiry take effect immediately
            // without a relaunch. These callbacks are `@ObservationIgnored` on
            // `PreferencesStore` so they don't add observer tracking churn.
            preferencesStore.onHistoryCapChanged = { [weak self] cap in
                self?.historyStore.enforceCap(cap)
            }
            preferencesStore.onAgeExpiryDaysChanged = { [weak self] days in
                if let days, days > 0 {
                    self?.historyStore.enforceAgeExpiry(days: days)
                }
            }
        }

        // Wire clipboard monitor to history store: new content is added to history.
        // The closure returns the UUID so the monitor can target follow-up OCR
        // updates to the created/promoted item.
        clipboardMonitor.onNewContent = { [weak self] representation in
            return self?.historyStore.addRepresentation(representation)
        }

        // Wire OCR completion to the history store.
        clipboardMonitor.onOCRCompleted = { [weak self] id, text in
            self?.historyStore.applyOCR(text, to: id)
        }

        // Start polling the system clipboard.
        clipboardMonitor.startMonitoring()

        // Create the popover content view with shared dependencies.
        // `dragStateChanged` lets `PopoverView` flip the popover's
        // `NSPopover.behavior` while a row-originated drag is in flight
        // so the popover stays visible for the duration of the drag.
        let popoverView = MainActor.assumeIsolated {
            PopoverView(
                store: historyStore,
                monitor: clipboardMonitor,
                preferences: preferencesStore,
                autoPasteService: autoPasteService,
                onDismiss: { [weak self] in
                    self?.statusBarController.dismissPopover()
                },
                dragStateChanged: { [weak self] isDragging in
                    if isDragging {
                        self?.statusBarController.setPopoverBehavior(.applicationDefined)
                    } else {
                        self?.statusBarController.restoreDefaultPopoverBehavior()
                    }
                }
            )
        }
        statusBarController.setup(with: popoverView)

        // Register the global shortcut. `KeyboardShortcuts` persists the
        // user-bound combination under the `.togglePopover` name and ships
        // Cmd+Shift+V as the baseline (see `PreferencesStore`).
        KeyboardShortcuts.onKeyDown(for: .togglePopover) { [weak self] in
            self?.statusBarController.togglePopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stopMonitoring()
    }
}
