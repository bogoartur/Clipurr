// PreferencesView.swift
// CopyCat
//
// Settings scene content for CopyCat.
//
// Presents a SwiftUI `Form` with four sections — General, Shortcuts,
// History, and Quick Paste — that bind to `PreferencesStore` (an
// `@Observable @MainActor` model) and drive side-effecting services
// (`LaunchAtLoginManager` for SMAppService registration).
//
// `PreferencesStore` is the single source of truth for user-tunable
// preferences and persists every change into `UserDefaults`. Because
// `HistoryCap` isn't a `Hashable` case-with-Int-associated-value shape
// that `Picker` can drive directly, we use a local `HistoryCapChoice`
// enum as the picker selection and translate to/from `HistoryCap` via
// computed bindings. Same pattern for age-expiry days.
//
// - Requirements: 1.5, 10.8, 11.1, 15.1, 15.5, 15.8

import SwiftUI
import AppKit
import KeyboardShortcuts

/// Picker-friendly representation of the history cap setting.
///
/// `HistoryCap` is `.finite(Int)` or `.unlimited`, which isn't a shape a
/// `Picker` can bind to directly. This enum flattens the three "preset"
/// values the Preferences UI exposes plus a `.custom` case that surfaces
/// an inline `TextField`.
private enum HistoryCapChoice: Hashable, CaseIterable, Identifiable {
    case fifty
    case twoHundred
    case fiveHundred
    case unlimited
    case custom

    var id: Self { self }

    var label: String {
        switch self {
        case .fifty:        return "50"
        case .twoHundred:   return "200"
        case .fiveHundred:  return "500"
        case .unlimited:    return "Unlimited"
        case .custom:       return "Custom"
        }
    }

    /// Maps a `HistoryCap` to the closest `HistoryCapChoice` for display.
    static func choice(from cap: HistoryCap) -> HistoryCapChoice {
        switch cap {
        case .finite(50):   return .fifty
        case .finite(200):  return .twoHundred
        case .finite(500):  return .fiveHundred
        case .finite:       return .custom
        case .unlimited:    return .unlimited
        }
    }
}

/// Picker-friendly representation of the age-expiry setting.
///
/// `ageExpiryDays` is `Int?` where `nil` means "off". This enum maps
/// that onto a picker-friendly set of presets plus a `.custom` case.
private enum AgeExpiryChoice: Hashable, CaseIterable, Identifiable {
    case off
    case sevenDays
    case thirtyDays
    case ninetyDays
    case custom

    var id: Self { self }

    var label: String {
        switch self {
        case .off:          return "Off"
        case .sevenDays:    return "7 days"
        case .thirtyDays:   return "30 days"
        case .ninetyDays:   return "90 days"
        case .custom:       return "Custom"
        }
    }

    /// Maps an optional day count to the closest `AgeExpiryChoice`.
    static func choice(from days: Int?) -> AgeExpiryChoice {
        switch days {
        case .none: return .off
        case .some(7):  return .sevenDays
        case .some(30): return .thirtyDays
        case .some(90): return .ninetyDays
        case .some:     return .custom
        }
    }
}

/// The Settings-scene content: a grouped SwiftUI form bound to
/// `PreferencesStore` with a side channel into `LaunchAtLoginManager`
/// for the SMAppService registration side effect.
@MainActor
struct PreferencesView: View {

    // MARK: - Inputs

    /// Observable store holding every user-tunable preference. Writes
    /// through `$preferences.someProperty` bindings persist automatically
    /// via the store's `didSet` handlers.
    @Bindable var preferences: PreferencesStore

    /// Drives the actual SMAppService registration. Kept out of
    /// `PreferencesStore` so the store stays free of AppKit/service
    /// side effects and remains easy to test.
    let launchAtLogin: LaunchAtLoginManager

    // MARK: - Local state

    /// Text buffer backing the "Custom" history-cap field. Parsed to
    /// `Int` on commit and pushed into `preferences.historyCap` when
    /// valid; invalid/empty input is ignored.
    @State private var customHistoryCapText: String = ""

    /// Text buffer backing the "Custom" age-expiry field. Parsed to
    /// `Int` on commit and pushed into `preferences.ageExpiryDays` when
    /// valid; invalid/empty input is ignored.
    @State private var customAgeDaysText: String = ""

    // MARK: - Init

    init(preferences: PreferencesStore, launchAtLogin: LaunchAtLoginManager) {
        self._preferences = Bindable(preferences)
        self.launchAtLogin = launchAtLogin

        // Seed the custom-field buffers from the current preferences so
        // the Custom row renders with the persisted value on first open.
        if case .finite(let n) = preferences.historyCap,
           ![50, 200, 500].contains(n) {
            self._customHistoryCapText = State(initialValue: String(n))
        }
        if let days = preferences.ageExpiryDays,
           ![7, 30, 90].contains(days) {
            self._customAgeDaysText = State(initialValue: String(days))
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            generalSection
            shortcutsSection
            historySection
            quickPasteSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 320)
        .onChange(of: preferences.launchAtLogin) { _, newValue in
            // Drive the real SMAppService registration. Keeping this in
            // the view (rather than `PreferencesStore.didSet`) means the
            // store remains a pure persistence layer and the AppKit
            // service-management call only fires from a UI context.
            launchAtLogin.setEnabled(newValue)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $preferences.launchAtLogin)

            Picker("Default re-copy format", selection: $preferences.defaultRecopyFormat) {
                Text("Rich text").tag(RecopyFormat.rich)
                Text("Plain text only").tag(RecopyFormat.plain)
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        Section("Shortcuts") {
            // The Recorder UI handles conflict detection and persists the
            // bound shortcut under `.togglePopover` via the
            // `KeyboardShortcuts` library.
            KeyboardShortcuts.Recorder("Toggle popover", name: .togglePopover)
        }
    }

    // MARK: - History

    private var historySection: some View {
        Section("History") {
            Picker("History size", selection: historyCapChoiceBinding) {
                ForEach(HistoryCapChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }

            if HistoryCapChoice.choice(from: preferences.historyCap) == .custom {
                TextField(
                    "Custom size",
                    text: $customHistoryCapText,
                    prompt: Text("Items")
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: customHistoryCapText) { _, newValue in
                    if let n = Int(newValue), n > 0 {
                        preferences.historyCap = .finite(n)
                    }
                }
            }

            Picker("Age expiry", selection: ageExpiryChoiceBinding) {
                ForEach(AgeExpiryChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }

            if AgeExpiryChoice.choice(from: preferences.ageExpiryDays) == .custom {
                TextField(
                    "Custom days",
                    text: $customAgeDaysText,
                    prompt: Text("Days")
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: customAgeDaysText) { _, newValue in
                    if let n = Int(newValue), n > 0 {
                        preferences.ageExpiryDays = n
                    }
                }
            }
        }
    }

    // MARK: - Quick Paste

    private var quickPasteSection: some View {
        Section("Quick Paste") {
            Toggle("Auto-paste after Cmd+1…Cmd+9", isOn: $preferences.autoPasteEnabled)

            Text("Requires Accessibility permission. You will be prompted the first time you enable this.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open Accessibility Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Picker Bindings

    /// Two-way binding that reads `preferences.historyCap` into a
    /// `HistoryCapChoice` for the picker and writes a resolved
    /// `HistoryCap` back. The `.custom` case resolves through
    /// `customHistoryCapText`; when that buffer doesn't parse to a
    /// positive `Int`, we seed `.finite(50)` so the store still holds a
    /// valid value until the user types a number.
    private var historyCapChoiceBinding: Binding<HistoryCapChoice> {
        Binding(
            get: { HistoryCapChoice.choice(from: preferences.historyCap) },
            set: { newChoice in
                switch newChoice {
                case .fifty:
                    preferences.historyCap = .finite(50)
                case .twoHundred:
                    preferences.historyCap = .finite(200)
                case .fiveHundred:
                    preferences.historyCap = .finite(500)
                case .unlimited:
                    preferences.historyCap = .unlimited
                case .custom:
                    if let n = Int(customHistoryCapText), n > 0 {
                        preferences.historyCap = .finite(n)
                    } else {
                        // No valid custom value yet — fall through to a
                        // sensible baseline so the `.finite` case anchors
                        // the Custom picker selection.
                        preferences.historyCap = .finite(50)
                    }
                }
            }
        )
    }

    /// Two-way binding that reads `preferences.ageExpiryDays` into an
    /// `AgeExpiryChoice` and writes back. The `.custom` case resolves
    /// through `customAgeDaysText`; when that buffer doesn't parse to a
    /// positive `Int`, we fall back to 7 days to keep the selection in
    /// the `.custom` bucket once chosen.
    private var ageExpiryChoiceBinding: Binding<AgeExpiryChoice> {
        Binding(
            get: { AgeExpiryChoice.choice(from: preferences.ageExpiryDays) },
            set: { newChoice in
                switch newChoice {
                case .off:
                    preferences.ageExpiryDays = nil
                case .sevenDays:
                    preferences.ageExpiryDays = 7
                case .thirtyDays:
                    preferences.ageExpiryDays = 30
                case .ninetyDays:
                    preferences.ageExpiryDays = 90
                case .custom:
                    if let n = Int(customAgeDaysText), n > 0 {
                        preferences.ageExpiryDays = n
                    } else {
                        preferences.ageExpiryDays = 7
                    }
                }
            }
        )
    }
}
