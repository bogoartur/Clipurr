// CopyCatApp.swift
// CopyCat
//
// Main entry point for the CopyCat menu bar clipboard manager.
// Uses SwiftUI lifecycle with an AppDelegate adaptor to bootstrap
// AppKit services (status bar, clipboard monitor, keyboard shortcut).
// LSUIElement = true in Info.plist ensures no Dock icon is shown.

import SwiftUI

@main
struct CopyCatApp: App {

    /// Bridges the SwiftUI lifecycle to the AppKit AppDelegate, which
    /// creates and wires all core services on launch.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — the app lives entirely in the menu bar.
        // The AppDelegate sets up the NSStatusItem and popover.
        //
        // The Settings scene body is lazy: it runs when the user opens
        // Preferences (Cmd+,), by which point `applicationDidFinishLaunching`
        // has already built `preferencesStore` and `launchAtLoginManager`.
        // `MainActor.assumeIsolated` matches the pattern used in AppDelegate
        // for touching main-actor-isolated state from non-isolated contexts
        // under Swift 6 strict concurrency.
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
