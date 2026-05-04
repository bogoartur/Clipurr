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
        Settings {
            EmptyView()
        }
    }
}
