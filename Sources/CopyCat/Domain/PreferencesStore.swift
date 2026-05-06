// PreferencesStore.swift
// CopyCat
//
// User-tunable preferences backed by `UserDefaults.standard`. Exposes the
// global shortcut name, history cap, age-based expiry, default re-copy
// format, auto-paste flag, and launch-at-login flag as observable
// properties. Each property writes through to `UserDefaults` on set, and
// `init()` reads them back, falling through to documented defaults when a
// key is absent.

import Foundation
import KeyboardShortcuts
import os.log

// MARK: - KeyboardShortcuts.Name registry

extension KeyboardShortcuts.Name {
    /// The user-customizable global shortcut that toggles the popover.
    ///
    /// The baseline is Cmd+Shift+V so existing users see no behavior
    /// change; `KeyboardShortcuts` persists the actual bound shortcut
    /// in `UserDefaults` internally keyed on the name string.
    static let togglePopover = Self(
        "togglePopover",
        default: .init(.v, modifiers: [.command, .shift])
    )
}

// MARK: - HistoryCap

/// The history retention cap policy.
///
/// Encodes as a single-key JSON object so new cases can be added later
/// without breaking existing persisted values:
///   - `.finite(n)`    → `{"finite": n}`
///   - `.unlimited`    → `{"unlimited": true}`
enum HistoryCap: Equatable {
    case finite(Int)
    case unlimited
}

extension HistoryCap: Codable {
    private enum CodingKeys: String, CodingKey {
        case finite
        case unlimited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try container.decodeIfPresent(Int.self, forKey: .finite) {
            self = .finite(n)
        } else if (try container.decodeIfPresent(Bool.self, forKey: .unlimited)) == true {
            self = .unlimited
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'finite' or 'unlimited' key in HistoryCap"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .finite(let n):
            try container.encode(n, forKey: .finite)
        case .unlimited:
            try container.encode(true, forKey: .unlimited)
        }
    }
}

// MARK: - RecopyFormat

/// Whether re-copy writes rich clipboard variants (RTF/HTML alongside plain)
/// or strips to plain text only.
enum RecopyFormat: String, Codable, CaseIterable {
    case rich
    case plain
}

// MARK: - PreferencesStore

/// Observable container for user-tunable preferences, auto-persisted to
/// `UserDefaults.standard` on every write.
///
/// The `globalShortcut` property names the `KeyboardShortcuts.Name` used by
/// the `KeyboardShortcuts` library; the actual bound shortcut (keys and
/// modifiers) is persisted by that library under the name string, not here.
@Observable
@MainActor
final class PreferencesStore {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let historyCap = "prefs.historyCap"
        static let ageExpiryDays = "prefs.ageExpiryDays"
        static let defaultRecopyFormat = "prefs.defaultRecopyFormat"
        static let autoPasteEnabled = "prefs.autoPasteEnabled"
        static let launchAtLogin = "prefs.launchAtLogin"
    }

    // MARK: - Logger

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.copycat.app",
        category: "PreferencesStore"
    )

    // MARK: - Stored Properties

    /// The name of the global shortcut that toggles the popover. The actual
    /// key/modifier binding is owned by `KeyboardShortcuts` and persisted
    /// in `UserDefaults` under the name string.
    let globalShortcut: KeyboardShortcuts.Name = .togglePopover

    /// Maximum number of non-pinned history items retained. Default: `.finite(50)`.
    var historyCap: HistoryCap = .finite(50) {
        didSet {
            persistHistoryCap(historyCap)
            onHistoryCapChanged?(historyCap)
        }
    }

    /// Age in days after which non-pinned items expire. `nil` disables expiry
    /// (default).
    var ageExpiryDays: Int? = nil {
        didSet {
            persistAgeExpiryDays(ageExpiryDays)
            onAgeExpiryDaysChanged?(ageExpiryDays)
        }
    }

    /// Whether re-copy writes rich clipboard variants by default. Default: `.rich`.
    var defaultRecopyFormat: RecopyFormat = .rich {
        didSet { persistDefaultRecopyFormat(defaultRecopyFormat) }
    }

    /// Whether quick-paste synthesizes Cmd+V into the previous app. Default: `false`.
    var autoPasteEnabled: Bool = false {
        didSet { persistAutoPasteEnabled(autoPasteEnabled) }
    }

    /// Whether the app is registered to launch at user login. Default: `false`.
    /// The actual `SMAppService` registration is driven by `LaunchAtLoginManager`;
    /// this flag is the persisted UI state that the view layer binds to.
    var launchAtLogin: Bool = false {
        didSet { persistLaunchAtLogin(launchAtLogin) }
    }

    // MARK: - Side-Effect Callbacks

    /// Invoked whenever `historyCap` changes. `AppDelegate` wires this to
    /// `HistoryStore.enforceCap(_:)` so the new cap takes effect immediately
    /// without requiring a relaunch (Requirement 15.8).
    @ObservationIgnored
    var onHistoryCapChanged: ((HistoryCap) -> Void)?

    /// Invoked whenever `ageExpiryDays` changes. `AppDelegate` wires this
    /// to `HistoryStore.enforceAgeExpiry(days:)` when a positive day count
    /// is set (Requirement 15.8).
    @ObservationIgnored
    var onAgeExpiryDaysChanged: ((Int?) -> Void)?

    // MARK: - Initialization

    /// Reads every preference from `UserDefaults.standard`, falling through
    /// to the documented defaults when a key is absent or malformed.
    init() {
        let defaults = UserDefaults.standard

        // historyCap — stored as JSON-encoded `Data` so the `.finite(n)` vs
        // `.unlimited` distinction is preserved in a single key.
        if let data = defaults.data(forKey: Keys.historyCap) {
            do {
                self.historyCap = try JSONDecoder().decode(HistoryCap.self, from: data)
            } catch {
                logger.warning(
                    "Failed to decode historyCap; falling back to .finite(50): \(error.localizedDescription, privacy: .public)"
                )
                self.historyCap = .finite(50)
            }
        } else {
            self.historyCap = .finite(50)
        }

        // ageExpiryDays — absence of the key means "off" (nil). We intentionally
        // use `object(forKey:)` so we can distinguish "key missing" from
        // "stored zero".
        if let raw = defaults.object(forKey: Keys.ageExpiryDays) as? Int {
            self.ageExpiryDays = raw
        } else {
            self.ageExpiryDays = nil
        }

        // defaultRecopyFormat
        if let raw = defaults.string(forKey: Keys.defaultRecopyFormat),
           let format = RecopyFormat(rawValue: raw) {
            self.defaultRecopyFormat = format
        } else {
            self.defaultRecopyFormat = .rich
        }

        // autoPasteEnabled — `bool(forKey:)` returns `false` when missing,
        // which matches the documented default.
        self.autoPasteEnabled = defaults.bool(forKey: Keys.autoPasteEnabled)

        // launchAtLogin
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    // MARK: - Persistence Helpers

    private func persistHistoryCap(_ cap: HistoryCap) {
        do {
            let data = try JSONEncoder().encode(cap)
            UserDefaults.standard.set(data, forKey: Keys.historyCap)
        } catch {
            logger.warning(
                "Failed to encode historyCap: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func persistAgeExpiryDays(_ days: Int?) {
        let defaults = UserDefaults.standard
        if let days {
            defaults.set(days, forKey: Keys.ageExpiryDays)
        } else {
            defaults.removeObject(forKey: Keys.ageExpiryDays)
        }
    }

    private func persistDefaultRecopyFormat(_ format: RecopyFormat) {
        UserDefaults.standard.set(format.rawValue, forKey: Keys.defaultRecopyFormat)
    }

    private func persistAutoPasteEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.autoPasteEnabled)
    }

    private func persistLaunchAtLogin(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.launchAtLogin)
    }
}
