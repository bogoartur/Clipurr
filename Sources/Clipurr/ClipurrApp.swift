// ClipurrApp.swift
// Clipurr
//
// Main entry point for the Clipurr menu bar clipboard manager.
// Uses SwiftUI lifecycle with an AppDelegate adaptor to bootstrap
// AppKit services (status bar, clipboard monitor, keyboard shortcut).
// LSUIElement = true in Info.plist ensures no Dock icon is shown.

import SwiftUI

@main
struct ClipurrApp: App {

    /// Bridges the SwiftUI lifecycle to the AppKit AppDelegate, which
    /// creates and wires all core services on launch.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — the app lives entirely in the menu bar.
        // The AppDelegate sets up the NSStatusItem and popover.
        //
        // SwiftUI can evaluate Settings before applicationDidFinishLaunching.
        // Its dependencies are initialized when the delegate is created.
        Settings {
            MainActor.assumeIsolated {
                PreferencesView(
                    preferences: appDelegate.preferencesStore,
                    launchAtLogin: appDelegate.launchAtLoginManager
                )
            }
        }
    }
}
