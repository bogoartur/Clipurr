# CopyCat — Handoff Notes

## What This Is

CopyCat is a native macOS 26 menu bar clipboard manager built with SwiftUI and Liquid Glass styling. The full implementation was scaffolded on Windows, so **nothing has been compiled or tested yet**. Your first step on the Mac should be building and running the test suite.

## Getting Started on Mac

```bash
# 1. Build the project
swift build

# 2. Run the existing unit tests
swift test

# 3. If the build fails, check Xcode 26 beta is installed
#    and that the macOS 26 SDK is available.
#    The Package.swift targets macOS .v15 as the minimum,
#    but Liquid Glass APIs (.glassEffect, GlassEffectContainer)
#    require the macOS 26 SDK.
```

If `swift build` complains about `GlassEffectContainer` or `.glassEffect()` not being found, you likely need Xcode 26 beta with the macOS 26 SDK. These are new APIs introduced in WWDC 2025.

## Project Structure

```
CopyCat/
├── Package.swift                          # SPM manifest (swift-tools-version: 6.1)
├── Sources/CopyCat/
│   ├── CopyCatApp.swift                   # @main entry point with AppDelegate adaptor
│   ├── Info.plist                         # LSUIElement = true (no Dock icon)
│   ├── Models/
│   │   └── ClipboardItem.swift            # ClipboardItemContent enum + ClipboardItem struct
│   ├── Domain/
│   │   ├── HistoryStore.swift             # @Observable history manager (add/delete/clear/recopy/search)
│   │   ├── PersistenceManager.swift       # JSON file persistence (atomic writes)
│   │   ├── ClipboardMonitor.swift         # NSPasteboard polling (0.5s timer)
│   │   └── LaunchAtLoginManager.swift     # SMAppService.mainApp wrapper
│   ├── AppKit/
│   │   ├── AppDelegate.swift              # Wires all components together
│   │   ├── StatusBarController.swift      # NSStatusItem + NSPopover (320×480, transient)
│   │   └── KeyboardShortcutManager.swift  # Cmd+Shift+V global hotkey
│   └── Views/
│       ├── PopoverView.swift              # Root view (GlassEffectContainer, search + list + clear)
│       ├── SearchBarView.swift            # Search field with match count
│       ├── ClipboardListView.swift        # ScrollView + LazyVStack with keyboard nav
│       └── ClipboardRowView.swift         # Single row with Liquid Glass .glassEffect()
└── Tests/CopyCatTests/
    ├── CopyCatTests.swift                 # Placeholder
    ├── ClipboardItemTests.swift           # Codable round-trip, textPreview tests
    └── HistoryStoreTests.swift            # addItem, deleteItem, clearAll, recopy, filter tests
```

## What Was Completed (Required Tasks)

All required (non-optional) tasks from the spec are implemented:

- **Task 1.1** — Project structure and SPM setup
- **Task 1.2** — ClipboardItem and ClipboardItemContent data models
- **Task 2.1** — PersistenceManager (JSON, atomic writes, graceful error handling)
- **Task 3.1** — HistoryStore (add, delete, clear, recopy, search, 50-item cap)
- **Task 4** — Domain layer checkpoint (diagnostics clean)
- **Task 5.1** — ClipboardMonitor (pasteboard polling, self-write detection)
- **Task 6.1** — StatusBarController (NSStatusItem + NSPopover)
- **Task 6.2** — KeyboardShortcutManager (Cmd+Shift+V)
- **Task 6.3** — AppDelegate (wires everything together)
- **Task 7** — AppKit bridge checkpoint (diagnostics clean)
- **Task 8.1** — ClipboardRowView (Liquid Glass styling)
- **Task 8.2** — SearchBarView
- **Task 8.3** — ClipboardListView (keyboard navigation)
- **Task 8.4** — PopoverView (GlassEffectContainer, confirmation dialog)
- **Task 9.1** — PopoverView wired to StatusBarController
- **Task 9.2** — LaunchAtLoginManager (SMAppService)
- **Task 10** — Final checkpoint (diagnostics clean)

## What Was Skipped (Optional Tasks)

These are all marked with `*` in `tasks.md` and can be done in a follow-up session:

### Property-Based Tests (SwiftCheck)
- **Task 1.3** — Serialization round-trip property test
- **Task 1.4** — Text preview truncation property test
- **Task 3.2** — Content prepend property test
- **Task 3.3** — Duplicate discard property test
- **Task 3.4** — Newest-first ordering property test
- **Task 3.5** — Re-copy preserves history property test
- **Task 3.6** — Delete removes exactly one item property test
- **Task 3.7** — History cap with eviction property test
- **Task 3.8** — Search filter correctness property test

### Unit Tests
- **Task 2.2** — PersistenceManager unit tests
- **Task 5.2** — ClipboardMonitor unit tests
- **Task 8.5** — SwiftUI view unit tests

### Integration Tests
- **Task 9.3** — Integration tests (persistence round-trip, keyboard shortcut, launch-at-login)

## Known Risks / Things to Verify on Mac

1. **Liquid Glass APIs** — `.glassEffect()`, `GlassEffectContainer`, and `.glassEffect(.regular.interactive())` are macOS 26 APIs. If the SDK isn't available, these will fail to compile. The fix is to install Xcode 26 beta.

2. **Swift 6 concurrency** — Package.swift uses swift-tools-version 6.1. If you hit Sendable or actor isolation warnings, you may need to add `@MainActor` annotations or adjust concurrency settings.

3. **SwiftCheck dependency** — The test target depends on `SwiftCheck 0.12.0+`. If it fails to resolve, check that the GitHub URL is reachable: `https://github.com/typelift/SwiftCheck.git`

4. **`.onKeyPress` availability** — `ClipboardListView` uses `.onKeyPress(.upArrow)` etc., which requires macOS 14+. This should be fine given the macOS 26 target.

5. **NSPasteboard in tests** — `HistoryStoreTests` includes a `recopy` test that doesn't actually write to the pasteboard (it uses a mock). But `ClipboardMonitor` tests (if written) will need pasteboard access.

## Next Session Instructions

To pick up where we left off, ask Kiro to:

> Run the optional tasks for the clipboard-manager spec. Start by building the project with `swift build` to verify everything compiles, then implement the skipped property-based tests and unit tests.

The spec files are at `.kiro/specs/clipboard-manager/` — requirements.md, design.md, and tasks.md have full details on every task and correctness property.
