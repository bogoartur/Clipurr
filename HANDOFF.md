# CopyCat — Handoff Notes

## What This Is

CopyCat is a native macOS 26 menu bar clipboard manager built with SwiftUI and Liquid Glass styling. The baseline (Requirements 1–8) was shipped and verified on a Mac in a previous session. This pass scaffolded the extended feature set (Requirements 9–17) on Windows; it compiles clean in the language server, but `swift build` / `swift test` haven't run yet. **First action on the Mac: build and test.**

## Getting Started on Mac

```bash
# 1. Fetch new dependencies (KeyboardShortcuts)
swift package resolve

# 2. Build the project — this will also fetch the package the first time
swift build

# 3. Run the test suite (existing baseline + new Property 8)
swift test

# 4. If the build complains about `glassEffect`, `GlassEffectContainer`,
#    `.buttonStyle(.glass)`, or `KeyboardShortcuts`, confirm you're on
#    Xcode 26 beta with the macOS 26 SDK and Swift 6.2 toolchain.
```

Package dependencies resolved by `swift build`:
- `SwiftCheck` 0.12.0+ (test target only)
- `KeyboardShortcuts` 2.2.0+ by Sindre Sorhus (main target; provides the customizable global shortcut + recorder UI)

## Project Structure

```
CopyCat/
├── Package.swift                           # SPM (swift-tools-version: 6.2, macOS 26)
├── Sources/CopyCat/
│   ├── CopyCatApp.swift                    # @main + Settings scene → PreferencesView
│   ├── Info.plist                          # LSUIElement = true
│   ├── Models/
│   │   └── ClipboardItem.swift             # .text/.image/.file + isPinned/rtfData/htmlData/ocrText
│   ├── Domain/
│   │   ├── HistoryStore.swift              # smart dedup, pins, cap/expiry, OCR, rich recopy
│   │   ├── PersistenceManager.swift        # atomic JSON writes
│   │   ├── ClipboardMonitor.swift          # polling + ContentTypeExtractor + OCR
│   │   ├── ContentTypeExtractor.swift      # file > text+rich > image priority
│   │   ├── OCRService.swift                # actor over VNRecognizeTextRequest
│   │   ├── OCRIndex.swift                  # UUID → OCR text cache
│   │   ├── SyntaxHighlighter.swift         # protocol + PlainMonospaceHighlighter
│   │   ├── CodeDetector.swift              # shebang + brace/keyword heuristics
│   │   ├── PreferencesStore.swift          # @Observable + UserDefaults + HistoryCap/RecopyFormat
│   │   ├── AutoPasteService.swift          # captures frontmost, CGEvent Cmd+V
│   │   └── LaunchAtLoginManager.swift      # SMAppService.mainApp
│   ├── AppKit/
│   │   ├── AppDelegate.swift               # wires everything
│   │   ├── StatusBarController.swift       # NSStatusItem + NSPopover + drag-safe behavior
│   │   └── PressureClickCatcher.swift      # Force Touch detection
│   └── Views/
│       ├── PopoverView.swift               # root view + drag mouse-up monitor
│       ├── SearchBarView.swift             # Liquid Glass capsule
│       ├── ClipboardListView.swift         # Cmd+1..9, Space preview, unified popover
│       ├── ClipboardRowView.swift          # pin indicator, .onDrag, context menu
│       ├── ClipboardItemPreview.swift      # rich/code/OCR/file branches
│       └── PreferencesView.swift           # Settings form (General/Shortcuts/History/Quick Paste)
└── Tests/CopyCatTests/
    ├── ClipboardItemTests.swift            # Codable round-trip, textPreview
    ├── ClipboardItemSerializationPropertyTests.swift  # Property 8 (SwiftCheck)
    ├── HistoryStoreTests.swift             # addItem, delete, clear, recopy, filter
    └── CopyCatTests.swift                  # placeholder
```

## What Was Completed (Required Tasks)

All required tasks from `tasks.md` are marked complete — tasks 1–10 from the original pass and tasks 11–24 from this pass. Full list:

### Baseline (previous sessions)
- 1.1 Project/SPM structure
- 1.2 Data models
- 2.1 PersistenceManager
- 3.1 HistoryStore core
- 4 Domain checkpoint
- 5.1 ClipboardMonitor
- 6.1 StatusBarController
- 6.2 KeyboardShortcutManager (replaced in 19.3)
- 6.3 AppDelegate
- 7 AppKit checkpoint
- 8.1–8.4 Row / Search / List / Popover views
- 9.1 PopoverView wired to StatusBarController
- 9.2 LaunchAtLoginManager
- 10 Final checkpoint

### Extension (this pass)
- 11.1 `.file([URL])` on ClipboardItemContent
- 11.2 `isPinned` / `rtfData` / `htmlData` / `ocrText` on ClipboardItem
- 12.1 PreferencesStore
- 13.1 OCRService (Vision)
- 13.2 OCRIndex
- 14.1 ContentTypeExtractor
- 15.1 SyntaxHighlighter protocol
- 15.2 PlainMonospaceHighlighter
- 15.3 CodeDetector
- 15.5 Splash/Sourceful deferral note
- 16 Domain additions checkpoint
- 17.1–17.7 HistoryStore extended (smart dedup, pin, cap, expiry, applyOCR, recopy-with-format)
- 18.1 Monitor rewired to ContentTypeExtractor
- 18.2 Monitor fires async OCR
- 19.1 KeyboardShortcuts package added
- 19.2 KeyboardShortcuts registered in AppDelegate
- 19.3 Hand-rolled KeyboardShortcutManager deleted
- 20.1 AutoPasteService
- 20.2 StatusBarController captures previous app on show
- 20.3 Cmd+1…Cmd+9 quick paste handler
- 21.1 Row extended (file rendering, pin indicator, drag, context menu)
- 21.2 Preview state lifted from row to list (unified Space + Force Touch)
- 21.3 Preview extended (file, rich text, code, OCR disclosure)
- 21.4 Arrow-key suspension while preview open
- 21.5 Popover behavior flip during drag
- 22.1 PreferencesView
- 22.2 Settings scene renders PreferencesView
- 23.1–23.5 Full AppDelegate wiring
- 24 Final checkpoint

## What Was Skipped (Optional Tasks, marked `- [ ]*`)

All optional property-based and unit test tasks are still skipped. Run them as follow-up when you want the formal correctness coverage:

- 1.3 Property 8 — **done** (committed separately, uses SwiftCheck)
- 1.4 Property 4 — Text preview truncation
- 2.2 PersistenceManager unit tests
- 3.2–3.8 Properties 1, 2, 3, 5, 6, 7, 9
- 5.2 ClipboardMonitor unit tests
- 8.5 SwiftUI view unit tests
- 9.3 Integration tests (done in earlier session)
- 11.3 Backward-compat decoding unit test
- 11.4 textPreview case tests
- 12.2 PreferencesStore unit tests
- 13.3 OCRService unit tests
- 13.4 Property 13 — OCR idempotence
- 14.2 ContentTypeExtractor unit tests
- 15.4 CodeDetector unit tests
- 17.8 Property 10 — Smart dedup invariant
- 17.9 Property 11 — Pin exempts from cap
- 17.10 Property 12 — Pin exempts from age expiry
- 17.11 Property 14 — Rich-preserving re-copy round-trip
- 17.12 Property 15 — File item URL round-trip
- 17.13 Property 16 — Search-with-OCR soundness
- 17.14 HistoryStore unit tests
- 18.3 ClipboardMonitor unit tests (rewired)
- 19.4 KeyboardShortcuts integration test
- 20.4 Quick-paste + AutoPasteService unit tests
- 21.6 View unit tests
- 22.3 PreferencesView unit tests
- 23.6 Full-launch integration test

## Known Risks / Things to Verify on Mac

1. **macOS 26 APIs** — `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `.onKeyPress(phases:)`, `ScrollViewReader.scrollTo(..., anchor: .center)` all require the macOS 26 SDK. Older SDKs will fail. Confirm Xcode 26 beta.

2. **Swift 6 concurrency** — `@MainActor` is used on `PreferencesStore`, `AutoPasteService`, `StatusBarController`, `PreferencesView`, `PopoverView`. `MainActor.assumeIsolated` is used in `AppDelegate` and `CopyCatApp` to touch main-actor state from NS-isolated contexts. If any warnings fire, they should be additive `@MainActor` annotations.

3. **`HistoryCap` picker binding** — The Preferences UI uses a local enum (`HistoryCapChoice`) with a custom-text buffer. If you select "Custom" and the text field is empty, the store falls back to `.finite(50)` until a positive integer is typed. If this feels jarring, the fallback can be changed to "preserve the current cap".

4. **Drag-out end detection** — We use `NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp)` to detect the end of a drag (SwiftUI's `.onDrag` has no end callback). If a drag is released on another app, the monitor may not fire. If that happens, a secondary safety net: a timer that resets `isDragInFlight` after ~5 seconds.

5. **`NSItemProvider` multi-file drag** — A single provider drags only the first file. Dragging multiple files as a group requires multiple providers, which SwiftUI's `.onDrag { NSItemProvider }` doesn't support directly. Use `.draggable` or register multiple types if needed.

6. **Auto-paste Accessibility** — First enable of "Auto-paste after Cmd+1…Cmd+9" will prompt the user for Accessibility permission. When denied, the re-copy still succeeds but the synthetic Cmd+V is skipped. A one-per-session banner is hooked via `AutoPasteService.onAccessibilityDenied` but not wired to a visual element yet — add a `.alert` in `PopoverView` or a system notification if you want the feedback surfaced.

7. **`KeyboardShortcuts` recorder** — Conflict detection is the library's responsibility. Reserved system shortcuts are rejected at the recorder level. If a specific combination isn't behaving the way you want, consult the library's docs.

8. **OCR timing** — `OCRService.recognize(imageData:)` runs off the main actor. For small screenshots it typically finishes in ~50–150 ms, but the first invocation in a session may take longer as Vision loads its models. The UI doesn't block on it — the OCR text populates lazily and the row updates via `@Observable`.

9. **`history.json` backward compatibility** — All new `ClipboardItem` fields decode via `decodeIfPresent`, so an existing `history.json` on your Mac should load cleanly. If decoding fails for individual items, they're skipped.

10. **Smart dedup and createdAt** — Promoting an existing non-pinned item to the top updates its `createdAt`. This means a smart-dedup match refreshes the age-expiry clock, which is intentional (users typically expect recent activity to "save" an item from expiry).

## Next Session Instructions

Three useful directions:

1. **Verify on macOS** — `swift build`, `swift test`, launch the app, test:
   - Copy text from multiple IDEs and check rich preview in Cmd+Shift+V
   - Copy a screenshot and confirm OCR populates after a moment
   - Copy a file in Finder and see it appear as a file item
   - Pin items and confirm they survive a new copy that would normally evict them
   - Drag a row into another app
   - Open Preferences, change the shortcut via the Recorder, change the cap, toggle auto-paste

2. **Run the optional test tasks** — ask Kiro to implement tasks 11.3, 11.4, 12.2, 13.3, 14.2, 15.4, 17.8–17.14, 18.3, 20.4 (and the rest). The property tests use SwiftCheck and live in `Tests/CopyCatTests/`.

3. **Pick a syntax highlighter** — either Splash or Sourceful. Add the package to `Package.swift`, create `SplashSyntaxHighlighter.swift` or `SourcefulSyntaxHighlighter.swift` in `Sources/CopyCat/Domain/`, conform to `SyntaxHighlighter`, then inject an instance via `PopoverView(syntaxHighlighter:)` or `ClipboardItemPreview(syntaxHighlighter:)` from `AppDelegate`. No other code changes needed.

Spec files at `.kiro/specs/clipboard-manager/` — `requirements.md`, `design.md`, `tasks.md`.
