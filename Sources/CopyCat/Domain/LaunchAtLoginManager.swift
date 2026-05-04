// LaunchAtLoginManager.swift
// CopyCat
//
// Manages the launch-at-login preference using SMAppService (macOS 13+).
// Provides a simple interface to check, enable, and disable automatic
// launch at user login.

import Foundation
import ServiceManagement
import os.log

// MARK: - LaunchAtLoginManager

/// Manages registering and unregistering the app for launch at login
/// using `SMAppService.mainApp`.
///
/// Usage:
/// ```swift
/// let manager = LaunchAtLoginManager()
/// manager.setEnabled(true)   // Register for launch at login
/// print(manager.isEnabled)   // Check current status
/// manager.setEnabled(false)  // Unregister
/// ```
struct LaunchAtLoginManager {

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.copycat.app",
        category: "LaunchAtLoginManager"
    )

    // MARK: - Properties

    /// The system service representing this app's login item registration.
    private var service: SMAppService {
        SMAppService.mainApp
    }

    /// Whether the app is currently registered to launch at login.
    ///
    /// Returns `true` when the login item status is `.enabled`.
    /// Returns `false` for all other states (`.notRegistered`,
    /// `.notFound`, `.requiresApproval`).
    var isEnabled: Bool {
        service.status == .enabled
    }

    // MARK: - Methods

    /// Enables or disables launch at login.
    ///
    /// Registers or unregisters the app as a login item using
    /// `SMAppService.mainApp`. Errors are logged but do not crash
    /// the app — the preference is best-effort.
    ///
    /// - Parameter enabled: `true` to register for launch at login,
    ///   `false` to unregister.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
                Self.logger.info("Registered for launch at login")
            } else {
                try service.unregister()
                Self.logger.info("Unregistered from launch at login")
            }
        } catch {
            Self.logger.warning(
                "Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)"
            )
        }
    }

    /// Toggles the current launch-at-login state.
    ///
    /// If currently enabled, unregisters. If currently disabled, registers.
    func toggle() {
        setEnabled(!isEnabled)
    }
}
