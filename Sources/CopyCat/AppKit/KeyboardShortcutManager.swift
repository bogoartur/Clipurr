// KeyboardShortcutManager.swift
// CopyCat
//
// Registers a global keyboard shortcut (Cmd+Shift+V) to toggle the popover.
// Uses both a global monitor (when the app is not focused) and a local monitor
// (when the app is focused) to ensure the shortcut works in all contexts.

import AppKit

final class KeyboardShortcutManager {

    // MARK: - Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var toggleAction: (() -> Void)?

    // MARK: - Public Methods

    /// Registers the Cmd+Shift+V keyboard shortcut to invoke the given toggle closure.
    ///
    /// - Parameter toggle: A closure called when the shortcut is detected.
    func register(toggle: @escaping () -> Void) {
        // Remove any existing monitors before registering new ones
        unregister()

        toggleAction = toggle

        // Global monitor: fires when the app is NOT the active application
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when the app IS the active application
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isShortcutMatch(event) == true {
                self?.toggleAction?()
                return nil // Consume the event
            }
            return event
        }
    }

    /// Removes both the global and local keyboard event monitors.
    func unregister() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        toggleAction = nil
    }

    // MARK: - Private Helpers

    /// Handles a key event from the global monitor.
    private func handleKeyEvent(_ event: NSEvent) {
        if isShortcutMatch(event) {
            toggleAction?()
        }
    }

    /// Returns `true` if the event matches Cmd+Shift+V.
    private func isShortcutMatch(_ event: NSEvent) -> Bool {
        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        return eventFlags == requiredFlags
            && event.charactersIgnoringModifiers?.lowercased() == "v"
    }
}
