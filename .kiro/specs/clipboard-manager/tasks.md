# Implementation Plan: CopyCat — Clipboard Manager

## Overview

This plan implements CopyCat as a native macOS 26 menu bar clipboard manager using SwiftUI with Liquid Glass styling and an AppKit bridge for status bar and popover control. Tasks are ordered to build the domain layer first (data models, persistence, history store), then the clipboard monitor, then the UI layer, and finally keyboard navigation and integration wiring. Each task builds incrementally on the previous ones so there is no orphaned code.

## Tasks

- [x] 1. Set up project structure and core data models
  - [x] 1.1 Create the Xcode project and Swift Package structure
    - Create a macOS App target named `CopyCat` with SwiftUI lifecycle
    - Set `LSUIElement = true` in Info.plist so the app has no Dock icon
    - Add SwiftCheck as a Swift Package dependency (test target only)
    - Create folder structure: `Sources/CopyCat/Models`, `Sources/CopyCat/Domain`, `Sources/CopyCat/Views`, `Sources/CopyCat/AppKit`, and `Tests/CopyCatTests`
    - _Requirements: 1.2_

  - [x] 1.2 Implement ClipboardItem and ClipboardItemContent data models
    - Create `ClipboardItemContent` enum with `.text(String)` and `.image(Data)` cases, conforming to `Codable` and `Equatable`
    - Create `ClipboardItem` struct with `id: UUID`, `content: ClipboardItemContent`, `createdAt: Date`, conforming to `Identifiable`, `Codable`, and `Equatable`
    - Implement a `textPreview` computed property on `ClipboardItem` that truncates text to 80 characters with an ellipsis (`…`) suffix when exceeded
    - _Requirements: 3.2, 6.5, 6.6_

  - [x] 1.3 Write property test for serialization round-trip
    - **Property 8: Serialization round-trip**
    - Implement `Arbitrary` conformance for `ClipboardItemContent` and `ClipboardItem` using SwiftCheck
    - Verify that encoding a `ClipboardItem` to JSON and decoding it back produces an equal item
    - Run a minimum of 100 iterations
    - **Validates: Requirements 6.5, 6.6**

  - [ ] 1.4 Write property test for text preview truncation
    - **Property 4: Text preview truncation**
    - For any text string, verify the preview is at most 80 characters; if the original exceeds 80 characters the preview ends with `…` and has length 80; if 80 or fewer the preview equals the original
    - Run a minimum of 100 iterations
    - **Validates: Requirements 3.2**

- [x] 2. Implement persistence layer
  - [x] 2.1 Implement PersistenceManager
    - Create `PersistenceManager` struct with static `save(_ items: [ClipboardItem])` and `load() -> [ClipboardItem]` methods
    - Use `JSONEncoder`/`JSONDecoder` with `.iso8601` date strategy
    - Store the history file at `~/Library/Application Support/CopyCat/history.json`
    - Create the Application Support subdirectory with `createDirectory(withIntermediateDirectories: true)` if it doesn't exist
    - Write atomically (write to temp file, then rename) to prevent corruption on termination
    - On decode failure (corrupted file), return an empty array and log a warning via `os_log`
    - _Requirements: 6.1, 6.2, 6.5_

  - [ ] 2.2 Write unit tests for PersistenceManager
    - Test save then load round-trip with known items produces equal results
    - Test that a corrupted JSON file results in an empty array (no crash)
    - Test that the Application Support directory is created if missing
    - _Requirements: 6.1, 6.2_

- [x] 3. Implement HistoryStore
  - [x] 3.1 Implement HistoryStore core logic
    - Create `HistoryStore` as an `@Observable` class holding `items: [ClipboardItem]` and `searchQuery: String`
    - Implement `addItem(_ content: ClipboardItemContent)`: check for duplicate against the most recent item, prepend new item, enforce 50-item cap by removing the oldest, call `saveToDisk()`
    - Implement `deleteItem(_ item: ClipboardItem)`: remove by ID, call `saveToDisk()`
    - Implement `clearAll()`: empty the array, call `saveToDisk()`
    - Implement `recopy(_ item: ClipboardItem, monitor: ClipboardMonitor)`: call `monitor.setIgnoreSelfWrite()`, write item content to `NSPasteboard.general`
    - Implement computed `filteredItems`: when `searchQuery` is non-empty, return text items whose content contains the query case-insensitively; when empty, return all items
    - Implement computed `matchCount`: count of `filteredItems`
    - Implement `loadFromDisk()` and `saveToDisk()` delegating to `PersistenceManager`
    - _Requirements: 2.2, 2.3, 2.4, 3.1, 4.3, 5.2, 5.3, 6.1, 6.3, 6.4, 7.2_

  - [ ] 3.2 Write property test for content prepend
    - **Property 1: Content prepend**
    - For any valid clipboard content added to a non-duplicate history, verify the new item appears at index 0 and history length increases by exactly one
    - Run a minimum of 100 iterations
    - **Validates: Requirements 2.2, 2.3**

  - [ ] 3.3 Write property test for duplicate discard
    - **Property 2: Duplicate discard**
    - For any content identical to the most recent item, verify the history remains completely unchanged after the add attempt
    - Run a minimum of 100 iterations
    - **Validates: Requirements 2.4**

  - [ ] 3.4 Write property test for newest-first ordering invariant
    - **Property 3: Newest-first ordering invariant**
    - For any sequence of add and delete operations, verify the resulting list is always ordered by `createdAt` descending
    - Run a minimum of 100 iterations
    - **Validates: Requirements 3.1**

  - [ ] 3.5 Write property test for re-copy preserves history
    - **Property 5: Re-copy preserves history**
    - For any history and any item within it, verify that re-copy does not change the history list, order, or content
    - Run a minimum of 100 iterations
    - **Validates: Requirements 4.3**

  - [ ] 3.6 Write property test for delete removes exactly one item
    - **Property 6: Delete removes exactly one item**
    - For any non-empty history and any item within it, verify deletion reduces length by one, the item is gone, and all other items remain in order
    - Run a minimum of 100 iterations
    - **Validates: Requirements 5.2**

  - [ ] 3.7 Write property test for history cap with eviction
    - **Property 7: History cap with eviction**
    - For any history (including full 50-item histories), verify that after adding a non-duplicate item the length is at most 50, the new item is at index 0, and the oldest item was evicted if at capacity
    - Run a minimum of 100 iterations
    - **Validates: Requirements 6.3, 6.4**

  - [ ] 3.8 Write property test for search filter correctness
    - **Property 9: Search filter correctness**
    - For any history of mixed text/image items and any non-empty query, verify: every result is a text item, every result contains the query case-insensitively, and no matching text item is missing
    - Run a minimum of 100 iterations
    - **Validates: Requirements 7.2**

- [x] 4. Checkpoint — Ensure all domain layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement ClipboardMonitor
  - [x] 5.1 Implement ClipboardMonitor
    - Create `ClipboardMonitor` as an `@Observable` class with a `Timer` polling `NSPasteboard.general.changeCount` every 0.5 seconds
    - Track `lastChangeCount` and `ignoreSelfWrite` flag
    - On change detected with `ignoreSelfWrite == false`: read pasteboard for `NSPasteboardTypeString` or image types (`TIFF`/`PNG`), convert images to PNG `Data` via `NSBitmapImageRep`, call `onNewContent` callback
    - On change detected with `ignoreSelfWrite == true`: reset the flag without creating an item
    - Implement `setIgnoreSelfWrite()` method
    - Skip items with no recognized content type; skip images exceeding 10 MB
    - Log warnings via `os_log` for image conversion failures
    - _Requirements: 2.1, 2.2, 2.3, 2.5_

  - [ ] 5.2 Write unit tests for ClipboardMonitor
    - Test that `setIgnoreSelfWrite()` causes the next change to be ignored
    - Test that the `ignoreSelfWrite` flag resets after one skip
    - _Requirements: 2.5_

- [x] 6. Implement AppKit bridge layer
  - [x] 6.1 Implement StatusBarController
    - Create `StatusBarController` class owning an `NSStatusItem` and `NSPopover`
    - Configure the status item with `doc.on.clipboard` SF Symbol as a template image
    - Set popover `contentSize` to 320×480 points and `behavior` to `.transient` for auto-dismiss on outside click
    - Implement `togglePopover()`, `showPopover()`, and `dismissPopover()` methods
    - Wire the status item button action to `togglePopover()`
    - _Requirements: 1.1, 1.3, 1.4_

  - [x] 6.2 Implement KeyboardShortcutManager
    - Create `KeyboardShortcutManager` class that registers `Cmd+Shift+V` using `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` and `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
    - Forward toggle events to `StatusBarController.togglePopover()`
    - Implement `register(toggle:)` and `unregister()` methods
    - _Requirements: 8.1_

  - [x] 6.3 Implement AppDelegate and app entry point
    - Create `AppDelegate` that sets `NSApp.setActivationPolicy(.accessory)` for no Dock icon
    - Instantiate `StatusBarController`, `HistoryStore`, `ClipboardMonitor`, and `KeyboardShortcutManager`
    - Wire `ClipboardMonitor.onNewContent` to `HistoryStore.addItem`
    - Call `HistoryStore.loadFromDisk()` on launch to restore persisted history
    - Start clipboard monitoring
    - Register the keyboard shortcut
    - _Requirements: 1.1, 1.2, 2.1, 6.2, 8.1_

- [x] 7. Checkpoint — Ensure AppKit bridge compiles and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement SwiftUI views with Liquid Glass styling
  - [x] 8.1 Implement ClipboardRowView
    - Create `ClipboardRowView` displaying a single `ClipboardItem`
    - For text items: show single-line preview truncated to 80 characters using the `textPreview` computed property
    - For image items: show thumbnail via `Image(nsImage:)` with `.frame(maxHeight: 60)` and `.aspectRatio(contentMode: .fit)`
    - Display relative timestamp using `RelativeDateTimeFormatter`
    - Apply `.glassEffect(.regular.interactive())` to each row for Liquid Glass styling
    - Support right-click context menu with a "Delete" option
    - Accept an `isFocused` parameter and show a highlight state when focused
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 4.4, 5.1_

  - [x] 8.2 Implement SearchBarView
    - Create `SearchBarView` with a text field and search icon
    - Bind to `HistoryStore.searchQuery`
    - Display the count of matching items when a search filter is active
    - _Requirements: 7.1, 7.2, 7.4_

  - [x] 8.3 Implement ClipboardListView
    - Create `ClipboardListView` using `ScrollView` + `LazyVStack` rendering `ClipboardRowView` for each item from `filteredItems`
    - Support arrow-key navigation via `@FocusState` tracking `focusedIndex`
    - On Enter key press, re-copy the focused item
    - On Escape key press, dismiss the popover
    - When history is empty, display a placeholder message
    - _Requirements: 3.1, 3.6, 8.2, 8.3, 8.4_

  - [x] 8.4 Implement PopoverView
    - Create `PopoverView` as the root view inside the popover
    - Wrap content in a `GlassEffectContainer` for Liquid Glass morphing and performance
    - Compose `SearchBarView`, `ClipboardListView`, and a "Clear All" button
    - On "Clear All" click, show a confirmation prompt before clearing
    - On item click: re-copy the item, show brief highlight animation feedback, then dismiss the popover
    - Wire dismiss action to `StatusBarController.dismissPopover()`
    - _Requirements: 3.1, 3.5, 4.1, 4.2, 4.3, 4.4, 5.3, 5.4, 7.1, 7.3_

  - [ ] 8.5 Write unit tests for SwiftUI views
    - Test that empty history renders the placeholder message
    - Test that image thumbnail has max height of 60 points
    - Test that `RelativeDateTimeFormatter` produces expected output for known dates
    - Test that "Clear All" triggers confirmation prompt
    - _Requirements: 3.3, 3.4, 3.6, 5.4_

- [x] 9. Wire everything together and implement launch-at-login
  - [x] 9.1 Connect PopoverView to StatusBarController
    - Set the `NSPopover.contentViewController` to host the `PopoverView` with the shared `HistoryStore` and `ClipboardMonitor` instances
    - Ensure the popover content receives the dismiss callback wired to `StatusBarController.dismissPopover()`
    - Verify the full flow: click status item → popover opens → click item → re-copy → popover dismisses
    - _Requirements: 1.3, 4.1, 4.2_

  - [x] 9.2 Implement launch-at-login preference
    - Add a launch-at-login toggle using `SMAppService.mainApp` (macOS 13+) or `ServiceManagement` framework
    - Store the preference and register/unregister accordingly
    - _Requirements: 1.5_

  - [x] 9.3 Write integration tests
    - Test persistence round-trip: save history to disk, load it back, verify equality
    - Test global keyboard shortcut registration
    - Test launch-at-login preference registration
    - _Requirements: 6.1, 8.1, 1.5_

- [x] 10. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Extend data model for new content and metadata
  - [ ] 11.1 Add `.file([URL])` case to `ClipboardItemContent`
    - Extend the `ClipboardItemContent` enum with a `.file([URL])` case
    - Add `case file` to the `CodingKeys`; encode as an array of URL strings and decode via `decodeIfPresent`, parsing each string with `URL(string:)` and dropping invalid entries
    - If the resulting URL array is empty after parsing, throw `DecodingError.dataCorrupted` so the surrounding item is skipped rather than silently becoming an empty file item
    - Update the `Equatable` synthesis (automatic via the new case) and confirm `.text` / `.image` / `.file` compare only within their own case
    - _Requirements: 17.1, 17.6_

  - [ ] 11.2 Extend `ClipboardItem` with pin, rich, and OCR metadata
    - Add `var isPinned: Bool = false`, `var rtfData: Data? = nil`, `var htmlData: Data? = nil`, and `var ocrText: String? = nil` stored properties on `ClipboardItem`
    - Implement a custom `init(from:)` that uses `decodeIfPresent` for every new field with the defaults above so older `history.json` files decode without error
    - Extend `textPreview` so that `.file(urls)` returns `urls[0].lastPathComponent` plus, when `urls.count > 1`, a `" +(n) more"` suffix; `.text` and `.image` branches keep their existing behavior
    - _Requirements: 12.8, 10.1, 10.2, 9.5, 17.1_

  - [ ]* 11.3 Write unit tests for backward-compatible decoding
    - Encode a hand-written JSON array that matches the pre-extension schema (only `id`, `content` with `text`/`image`, `createdAt`) and assert it decodes into `[ClipboardItem]` with `isPinned == false`, `rtfData == nil`, `htmlData == nil`, `ocrText == nil`
    - Encode a JSON document where one entry has `content: { "file": [] }` (empty URL list) and assert that the surrounding history still decodes but the empty-file entry is dropped
    - _Requirements: 6.2_

  - [ ]* 11.4 Write unit tests for the extended `textPreview`
    - Assert `.text("hello")` → `"hello"`
    - Assert `.image(Data([...]))` → `"[Image]"`
    - Assert `.file([fileURL("README.md")])` → `"README.md"`
    - Assert `.file([fileURL("a.txt"), fileURL("b.txt"), fileURL("c.txt")])` → `"a.txt +2 more"`
    - _Requirements: 17.1_

- [ ] 12. Add PreferencesStore
  - [ ] 12.1 Implement `PreferencesStore` and the `togglePopover` shortcut name
    - Create `Sources/CopyCat/Domain/PreferencesStore.swift` with a `HistoryCap` enum (`.finite(Int)` and `.unlimited`, `Codable` via a single-key container) and a `RecopyFormat` enum (`.rich`, `.plain`)
    - Create `PreferencesStore` as an `@Observable @MainActor final class` with stored properties `globalShortcut: KeyboardShortcuts.Name`, `historyCap: HistoryCap`, `ageExpiryDays: Int?`, `defaultRecopyFormat: RecopyFormat`, `autoPasteEnabled: Bool`, `launchAtLogin: Bool`
    - Each property has a `didSet` that writes into `UserDefaults.standard` under a stable `prefs.*` key; an `init()` reads the defaults back, falling through to the documented defaults when a key is absent
    - Declare `extension KeyboardShortcuts.Name { static let togglePopover = Self("togglePopover", default: .init(.v, modifiers: [.command, .shift])) }` in the same file so Cmd+Shift+V is the baseline
    - _Requirements: 10.8, 11.2, 15.2, 15.6, 15.8, 11.7_

  - [ ]* 12.2 Write unit tests for PreferencesStore
    - Assert `HistoryCap` round-trips through `JSONEncoder` / `JSONDecoder` for both `.finite(n)` and `.unlimited`
    - Assert that writing each `PreferencesStore` property updates `UserDefaults.standard` under its documented key (using a `UserDefaults(suiteName:)` scoped to the test)
    - Assert that `PreferencesStore()` on empty defaults yields `historyCap == .finite(50)`, `ageExpiryDays == nil`, `defaultRecopyFormat == .rich`, `autoPasteEnabled == false`
    - _Requirements: 10.8, 11.2, 11.7, 15.2, 15.6_

- [ ] 13. Add OCR subsystem
  - [ ] 13.1 Implement `OCRService`
    - Create `Sources/CopyCat/Domain/OCRService.swift` with an `actor OCRService` that owns a `recognitionLanguages: [String]` array defaulted to at least 8 entries (`en-US`, `de-DE`, `fr-FR`, `es-ES`, `it-IT`, `pt-BR`, `ja-JP`, `zh-Hans`)
    - Implement `func recognize(imageData: Data) async -> String` that decodes `Data → CGImage` via `CGImageSourceCreateWithData`, runs a `VNRecognizeTextRequest` with `recognitionLevel = .accurate`, `recognitionLanguages = self.recognitionLanguages`, and `usesLanguageCorrection = true`, and returns the joined top candidates separated by newlines
    - Any decode, `VNImageRequestHandler.perform` throw, or empty observations path returns `""` and logs via `os_log`
    - _Requirements: 9.1, 9.2, 9.8_

  - [ ] 13.2 Implement `OCRIndex`
    - Create `Sources/CopyCat/Domain/OCRIndex.swift` with `@Observable final class OCRIndex` exposing `private(set) var texts: [UUID: String] = [:]`, `func set(_ text: String, for id: UUID)`, and `func clear(for id: UUID)`
    - _Requirements: 9.6_

  - [ ]* 13.3 Write unit tests for OCRService
    - Assert `OCRService().recognitionLanguages.count >= 8`
    - Assert that `recognize(imageData: garbageBytes)` returns `""` (exercises the decode-failure branch)
    - Assert that `recognize(imageData:)` called twice with the same small stub PNG returns the same string (idempotence smoke)
    - _Requirements: 9.1, 9.2, 9.8_

  - [ ]* 13.4 Write property test for OCR idempotence
    - **Property 13: OCR idempotence**
    - Using SwiftCheck, generate a small `Arbitrary` PNG blob (or reuse the existing fixed fixtures) and assert that `OCRService.recognize(imageData: bytes)` returns the same string across two calls, and that calling `HistoryStore.applyOCR(text, to: id)` two or more times with the same `(text, id)` leaves the history equal to the single-application result
    - Run a minimum of 100 iterations
    - **Validates: Requirements 9.4, 9.5**

- [ ] 14. Add ContentTypeExtractor
  - [ ] 14.1 Implement `ContentTypeExtractor`
    - Create `Sources/CopyCat/Domain/ContentTypeExtractor.swift` with `enum ContentTypeExtractor { static func extract(from pasteboard: NSPasteboard) -> ClipboardItemRepresentation? }`
    - Define `struct ClipboardItemRepresentation: Equatable` with `enum Payload: Equatable { case text(plain: String, rtf: Data?, html: Data?); case image(Data); case file([URL]) }` and a single `payload` field
    - Priority order inside `extract`: file URLs (via `.fileURL` / `public.file-url`) first; then text (read `.string`, and alongside try `.rtf` and `.html`; derive plain from rich via `NSAttributedString(data:options:documentAttributes:)` when plain is absent); then image (PNG, or TIFF converted to PNG via `NSBitmapImageRep`, preserving the existing 10 MB size cap)
    - Return `nil` when no recognized type is found
    - _Requirements: 10.1, 10.2, 17.2_

  - [ ]* 14.2 Write unit tests for ContentTypeExtractor
    - Pasteboard with only plain text → `.text(plain:, rtf: nil, html: nil)`
    - Pasteboard with plain text and RTF → `.text(plain:, rtf: .some, html: nil)`
    - Pasteboard with plain text and HTML → `.text(plain:, rtf: nil, html: .some)`
    - Pasteboard with TIFF image only → `.image(pngData)` (bytes decode to a valid PNG)
    - Pasteboard with a single file URL → `.file([url])`
    - Pasteboard with multiple file URLs → `.file([u1, u2, ...])` in pasteboard order
    - Pasteboard with both file URLs and plain text → `.file([...])` (file wins per the priority order)
    - _Requirements: 10.1, 10.2, 17.2_

- [ ] 15. Add SyntaxHighlighter protocol and plain fallback
  - [ ] 15.1 Define the `SyntaxHighlighter` protocol
    - Create `Sources/CopyCat/Domain/SyntaxHighlighter.swift` with `protocol SyntaxHighlighter { func highlight(_ source: String, language: String?) -> NSAttributedString }`
    - _Requirements: 10.4, 10.5_

  - [ ] 15.2 Implement `PlainMonospaceHighlighter`
    - In the same file, add `struct PlainMonospaceHighlighter: SyntaxHighlighter` whose `highlight(_:language:)` returns an `NSAttributedString` built from the raw source string with a single attribute `[.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]`, ignoring the `language` hint
    - This implementation stays in place until a concrete highlighting library is chosen; all callers depend on the protocol, never on the fallback concrete type
    - _Requirements: 10.4_

  - [ ] 15.3 Implement `CodeDetector`
    - Create `Sources/CopyCat/Domain/CodeDetector.swift` with `enum CodeDetector { struct Verdict: Equatable { let isCode: Bool; let language: String? }; static func detect(_ source: String) -> Verdict }`
    - Return `Verdict(isCode: false, language: nil)` for sources shorter than 20 characters or containing no structural punctuation (`{`, `}`, `;`, `:`, `=`)
    - Score the source using brace/semicolon density, shebang detection on the first line (`swift`, `python`, `bash`, `node`), and keyword matches per language (`swift`: `func`, `let`, `var`, `struct`, `class`, `guard`; `python`: `def`, `import`, `class`, `if __name__`; `javascript`: `function`, `const`, `let`, `=>`; `json`: leading `{` or `[` with balanced braces)
    - Return the highest-scoring language as `Verdict(isCode: true, language: "<lang>")` when the combined score crosses a configured threshold; otherwise `Verdict(isCode: false, language: nil)`
    - _Requirements: 10.4_

  - [ ]* 15.4 Write unit tests for CodeDetector
    - Assert a short `"hi"` string returns `Verdict(isCode: false, language: nil)`
    - Assert a plain prose paragraph (80+ chars, no `{}`/`;`) returns `Verdict(isCode: false, language: nil)`
    - Assert a small Swift snippet (`func foo() { let x = 1 }`) returns `Verdict(isCode: true, language: "swift")`
    - Assert a Python snippet (`def main():\n    import os`) returns `Verdict(isCode: true, language: "python")`
    - Assert a JavaScript snippet (`const add = (a, b) => a + b;`) returns `Verdict(isCode: true, language: "javascript")`
    - Assert a JSON snippet (`{ "a": 1 }`) returns `Verdict(isCode: true, language: "json")`
    - _Requirements: 10.4_

  - [ ] 15.5 Record the highlighter-library-selection deferral
    - Add a `// NOTE:` comment block at the top of `SyntaxHighlighter.swift` explaining that the concrete library choice between [Splash](https://github.com/JohnSundell/Splash) and [Sourceful](https://github.com/louisdh/sourceful) is deferred to a follow-up and that a single adapter file (e.g. `SplashSyntaxHighlighter.swift` or `SourcefulSyntaxHighlighter.swift`) can later be added beside this file without touching the view layer
    - This task is documentation-only and does not ship a library adapter
    - _Requirements: 10.4, 10.5_

- [ ] 16. Checkpoint — Domain additions compile and existing tests still pass
  - Run `swift build` and confirm zero warnings / errors across the new domain files (`PreferencesStore`, `OCRService`, `OCRIndex`, `ContentTypeExtractor`, `SyntaxHighlighter`, `PlainMonospaceHighlighter`, `CodeDetector`) and the extended `ClipboardItem` / `ClipboardItemContent`
    - Run `swift test` and confirm that the existing baseline tests from tasks 1–10 still pass with no regressions
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 17. Extend HistoryStore for smart dedup, pins, cap, expiry, rich recopy
  - [ ] 17.1 Implement smart-dedup `addRepresentation(_:)`
    - Add `func addRepresentation(_ rep: ClipboardItemRepresentation)` on `HistoryStore`
    - When the representation's content equals an existing **non-pinned** item's content at any position, remove that item, update its `createdAt = Date()`, merge in any newly-present `rtfData` / `htmlData`, re-insert at index 0, and leave `items.count` unchanged
    - When the representation's content equals an existing **pinned** item's content, leave the pinned item in place, still run the non-pinned dedup check so no new non-pinned duplicate is created, and do nothing further if no non-pinned match exists (Req 16.3)
    - When no match exists, insert a new `ClipboardItem` at index 0 as today
    - Persist via `saveToDisk()`
    - _Requirements: 16.1, 16.2, 16.3, 16.4_

  - [ ] 17.2 Implement `togglePin(_:)`
    - Add `func togglePin(_ item: ClipboardItem)` that flips `isPinned` on the matching item (by `id`) and persists
    - Do not mutate `items` order directly — ordering is derived by `filteredItems`
    - _Requirements: 12.1, 12.2, 12.3, 12.8_

  - [ ] 17.3 Extend `filteredItems` with OCR-match and pinned-first sort
    - Update `filteredItems` so that, after filtering, items are sorted with `isPinned == true` first, then by `createdAt` descending
    - Extend the filter predicate so that, for `.text(s)`, the item matches when `s` OR `item.ocrText` contains the query; for `.image`, the item matches when `item.ocrText` contains the query; for `.file(urls)`, the item matches when any URL's `lastPathComponent` or full `path` contains the query
    - _Requirements: 9.6, 12.4_

  - [ ] 17.4 Implement `enforceCap(_ cap: HistoryCap)`
    - When `cap == .unlimited`, return without change
    - Otherwise, count only non-pinned items; while that count exceeds `n` (for `cap == .finite(n)`), remove the oldest non-pinned item (smallest `createdAt`)
    - Never remove pinned items
    - Persist after eviction
    - _Requirements: 12.6, 15.3, 15.4_

  - [ ] 17.5 Implement `enforceAgeExpiry(days:)`
    - Add `func enforceAgeExpiry(days: Int)` that removes every non-pinned item whose `createdAt` is older than `days * 86400` seconds from `Date()`, leaves pinned items untouched, and persists when any item was removed
    - _Requirements: 12.7, 15.7_

  - [ ] 17.6 Implement `applyOCR(_:to:)`
    - Add `func applyOCR(_ text: String, to id: UUID)` that updates `ocrText` on the matching item, mirrors the value into `ocrIndex.set(text, for: id)`, and persists
    - Writing the same `(text, id)` tuple a second time must produce a state equal to the first write (idempotent); guard with an equality check before persist
    - _Requirements: 9.4, 9.5_

  - [ ] 17.7 Extend `recopy(_:writer:format:)` for rich and file items
    - Change the signature to `func recopy(_ item: ClipboardItem, writer: ClipboardWritable, format: RecopyFormat = .rich)`
    - Preserve the existing `ignoreSelfWrite` handshake
    - For `.text` items with `format == .rich`: write the plain string under `.string`, and when present also write `rtfData` under `.rtf` and `htmlData` under `.html`
    - For `.text` items with `format == .plain`: write only the plain string under `.string`, even if rich variants exist
    - For `.image` items: unchanged (`.png`)
    - For `.file(urls)` items: call `NSPasteboard.general.writeObjects(urls as [NSURL])` so Finder receives a proper file paste
    - `recopy` never mutates `items` (Property 5 preserved)
    - _Requirements: 10.6, 10.7, 17.5_

  - [ ]* 17.8 Write property test for smart dedup invariant
    - **Property 10: Smart dedup invariant**
    - Using SwiftCheck, generate an arbitrary history `H` plus a representation `R` whose content equals the content of an existing non-pinned item at some index `k`; after invoking `addRepresentation(R)` assert that `|H'| == |H|`, the item with content `R.content` is at index 0 of `H'`, every pinned item retains its `id`/`content`/`createdAt`/`isPinned`, and no new non-pinned item was created
    - Run a minimum of 100 iterations
    - **Validates: Requirements 16.1, 16.2, 16.3, 16.4**

  - [ ]* 17.9 Write property test for pin exempts from cap
    - **Property 11: Pin exempts from cap**
    - Using SwiftCheck, generate an arbitrary history `H` with `P` pinned items and a random cap `n > 0`, add an arbitrary sequence of non-pinned items, then call `enforceCap(.finite(n))`; assert non-pinned count ≤ `n`, pinned count == `P`, and every pinned item is preserved byte-for-byte. Also verify `enforceCap(.unlimited)` is a no-op after any sequence of additions
    - Run a minimum of 100 iterations
    - **Validates: Requirements 12.6, 15.3, 15.4**

  - [ ]* 17.10 Write property test for pin exempts from age expiry
    - **Property 12: Pin exempts from age expiry**
    - Using SwiftCheck, generate an arbitrary history `H` and any positive `T` days; assert that after `enforceAgeExpiry(days: T)`, every pinned item in `H` is still present in `H'` with identical `id`, `content`, `createdAt`, and `isPinned == true`, regardless of how old its `createdAt` is
    - Run a minimum of 100 iterations
    - **Validates: Requirements 12.7, 15.7**

  - [ ]* 17.11 Write property test for rich-preserving re-copy round-trip
    - **Property 14: Rich-preserving re-copy round-trip**
    - Using SwiftCheck, generate an arbitrary `ClipboardItem` with non-nil `rtfData` and/or `htmlData`; call `recopy(item, writer:, format: .rich)` onto a fresh in-memory `NSPasteboard`, then read it back via `ContentTypeExtractor.extract(from:)` and assert plain text equals the original, `rtf` bytes equal `item.rtfData` when present, and `html` bytes equal `item.htmlData` when present
    - Run a minimum of 100 iterations
    - **Validates: Requirements 10.1, 10.2, 10.6**

  - [ ]* 17.12 Write property test for file item URL round-trip
    - **Property 15: File item URL round-trip**
    - Using SwiftCheck, generate a non-empty list of file URLs, construct a `ClipboardItem` with `content: .file(urls)`, encode it via `JSONEncoder`, decode back via `JSONDecoder`, and assert the resulting item's `.file` array equals the original (same order, same URL values)
    - Run a minimum of 100 iterations
    - **Validates: Requirements 17.6**

  - [ ]* 17.13 Write property test for search-with-OCR soundness
    - **Property 16: Search-with-OCR soundness**
    - Using SwiftCheck, generate an arbitrary history of mixed text/image/file items (with arbitrary `ocrText` on images) and an arbitrary non-empty query; assert every item in `filteredItems` satisfies at least one of: text content contains the query case-insensitively, `ocrText` contains the query case-insensitively, or a file URL's `lastPathComponent`/`path` contains the query case-insensitively; and that no item in the full history that satisfies these predicates is missing from `filteredItems`
    - Run a minimum of 100 iterations
    - **Validates: Requirements 9.6, 7.2**

  - [ ]* 17.14 Write unit tests for HistoryStore extensions
    - Test `togglePin` flips `isPinned` and persists through a save/load round-trip
    - Test `enforceCap(.finite(3))` on a 5-non-pinned + 2-pinned history leaves 3 non-pinned + 2 pinned
    - Test `addRepresentation` against a matching non-pinned item promotes it to index 0 without duplication
    - Test `addRepresentation` against a matching pinned item leaves the history byte-for-byte equal (Req 16.3)
    - Test `enforceAgeExpiry(days: 1)` removes non-pinned items older than 1 day and retains all pinned items regardless of age
    - Test `recopy(item, writer:, format: .plain)` on a rich item writes only `.string` (no `.rtf`/`.html` on the pasteboard)
    - _Requirements: 12.1–12.8, 15.3, 15.4, 15.7, 16.1–16.4, 10.6, 10.7_

- [ ] 18. Rewire ClipboardMonitor
  - [ ] 18.1 Replace direct pasteboard reading with `ContentTypeExtractor`
    - Inject `extractor: ContentTypeExtractor.Type = ContentTypeExtractor.self` on `ClipboardMonitor` (or accept it via the initializer for testability)
    - Replace `readContent(from:)` with a call to `extractor.extract(from: pasteboard)`
    - Change `onNewContent` to `((ClipboardItemRepresentation) -> Void)?` and remove the old `ClipboardItemContent` callback
    - _Requirements: 10.1, 10.2, 17.2_

  - [ ] 18.2 Fire async OCR for image representations
    - Inject `ocrService: OCRService` and `var onOCRCompleted: ((UUID, String) -> Void)?`
    - When the extracted representation is `.image(data)`, after handing off to `onNewContent`, launch a `Task.detached` that calls `await ocrService.recognize(imageData: data)` and, on the `@MainActor`, invokes `onOCRCompleted(id, text)` where `id` is obtained from the downstream `HistoryStore` (via a small `lastInsertedImageID` hook the monitor exposes, or by having the store expose the id through the representation path)
    - _Requirements: 9.3, 9.4_

  - [ ]* 18.3 Write unit tests for the rewired monitor
    - Use a spy `ContentTypeExtractor` that returns a fixed `.text(plain:, rtf:, html:)` representation and assert that `onNewContent` fires once with that representation after a `changeCount` bump
    - Use a spy `OCRService` that records calls; assert that an `.image(data)` representation eventually triggers `onOCRCompleted(id, "…text…")`
    - _Requirements: 9.3, 9.4, 10.1, 10.2, 17.2_

- [ ] 19. Replace KeyboardShortcutManager with the KeyboardShortcuts library
  - [ ] 19.1 Add the `KeyboardShortcuts` package dependency
    - In `Package.swift`, append `.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0")` to `dependencies` and add `.product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")` to the `CopyCat` target's `dependencies`
    - Commit the updated `Package.resolved`
    - _Requirements: 11.1, 11.3_

  - [ ] 19.2 Register the toggle shortcut via the library
    - In `AppDelegate.applicationDidFinishLaunching`, replace the `KeyboardShortcutManager.register { ... }` call with `KeyboardShortcuts.onKeyDown(for: .togglePopover) { [weak self] in self?.statusBarController.togglePopover() }`
    - The `KeyboardShortcuts.Name.togglePopover` declaration from task 12.1 carries the Cmd+Shift+V default, preserving the baseline
    - _Requirements: 11.3_

  - [ ] 19.3 Remove the hand-rolled `KeyboardShortcutManager`
    - Delete `Sources/CopyCat/AppKit/KeyboardShortcutManager.swift`
    - Remove the `keyboardShortcutManager` property and `unregister()` call from `AppDelegate`
    - If any test file still references the deleted type, update it to exercise the library's `KeyboardShortcuts.onKeyDown` integration instead
    - _Requirements: 11.3 (cleanup)_

  - [ ]* 19.4 Write integration test for the library binding
    - In a test that runs on the main actor, call `KeyboardShortcuts.setShortcut(KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .option]), for: .togglePopover)` and assert `KeyboardShortcuts.getShortcut(for: .togglePopover)` returns that value
    - Restore the default via `KeyboardShortcuts.reset(.togglePopover)` in a `defer`
    - _Requirements: 11.1, 11.3_

- [ ] 20. Add Quick Paste and Auto Paste
  - [ ] 20.1 Implement `AutoPasteService`
    - Create `Sources/CopyCat/Domain/AutoPasteService.swift` with `@MainActor final class AutoPasteService` and a private `previousApp: NSRunningApplication?`
    - `func capturePreviousFrontmostApp()` snapshots `NSWorkspace.shared.frontmostApplication`
    - `func pasteIntoPreviousApp()` returns early when `previousApp == nil`; calls `AXIsProcessTrusted()`, and when `false` invokes `promptForAccessibilityIfNeeded()` and returns; otherwise activates the captured app via `previousApp?.activate(options: [])`, then `DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)` posts key-down / key-up `CGEvent`s for `kVK_ANSI_V` with `.maskCommand` to `.cghidEventTap`
    - `func promptForAccessibilityIfNeeded() -> Bool` calls `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)` and returns the trust state; a one-per-session banner or alert explains that auto-paste is skipped when denied
    - _Requirements: 11.8, 11.9, 11.10_

  - [ ] 20.2 Capture the previous frontmost app when the popover shows
    - In `StatusBarController`, add an injected `autoPasteService: AutoPasteService`
    - At the top of `showPopover()`, call `autoPasteService.capturePreviousFrontmostApp()` **before** `popover.show(relativeTo:...)` so we snapshot the caller before CopyCat takes focus
    - _Requirements: 11.8_

  - [ ] 20.3 Implement the Cmd+1…Cmd+9 quick-paste handler
    - In `ClipboardListView`, inject `preferences: PreferencesStore`, `autoPasteService: AutoPasteService`, `store: HistoryStore`, and `monitor: ClipboardMonitor` (via the existing `PopoverView` props)
    - Attach nine `.onKeyPress(keys: [.init("1")], phases: .down)` … `.onKeyPress(keys: [.init("9")], phases: .down)` modifiers, each gated by `.modifiers(.command)` when the API supports it (or by inspecting `press.modifiers` inside the handler)
    - On match, call a single `quickPasteHandler(_ digit: Int)` helper: compute `index = digit - 1`, guard `filteredItems.indices.contains(index)` (out-of-bounds → return `.handled` and do nothing), then `store.recopy(filteredItems[index], writer: monitor, format: preferences.defaultRecopyFormat)`, if `preferences.autoPasteEnabled` call `autoPasteService.pasteIntoPreviousApp()`, then `onDismiss()`
    - _Requirements: 11.5, 11.6, 11.7, 11.8_

  - [ ]* 20.4 Write unit tests for the quick-paste handler and AutoPasteService
    - With a 5-item filtered list, assert that invoking `quickPasteHandler(3)` calls `store.recopy` on `filteredItems[2]`
    - With a 3-item filtered list, assert that invoking `quickPasteHandler(9)` does not call `store.recopy` and does not call `autoPasteService.pasteIntoPreviousApp` (state unchanged)
    - With `autoPasteEnabled == false`, assert that `quickPasteHandler(1)` re-copies but does not call `pasteIntoPreviousApp`
    - With `autoPasteEnabled == true` and a spy `AutoPasteService` whose `AXIsProcessTrusted()` stub returns `false`, assert that `pasteIntoPreviousApp` records the attempted call, reports the denial via the one-shot banner hook, and does not post a `CGEvent`
    - _Requirements: 11.5, 11.6, 11.7, 11.8, 11.9, 11.10_

- [ ] 21. Extend SwiftUI views for files, pins, drag, preview lift, and OCR
  - [ ] 21.1 Extend `ClipboardRowView` for file items, pins, and drag
    - Add a `.file(urls)` branch to `contentPreview`: an `NSWorkspace.shared.icon(forFile: urls[0].path)` rendered via `Image(nsImage:)` at 28×28, `urls[0].lastPathComponent` as the main label, and when `urls.count > 1` a secondary `"+(urls.count - 1) more"` label on the same row
    - When `FileManager.default.fileExists(atPath: urls[0].path) == false`, render the label with `.foregroundStyle(.secondary)` and a `.strikethrough()` modifier (stale indicator)
    - When `item.isPinned`, overlay a small `Image(systemName: "pin.fill")` in the top-leading corner of the row
    - Extend the context menu with `Button("Pin") { ... }` / `Button("Unpin") { ... }` (toggled by `item.isPinned`) calling `onTogglePin`, and for file items a `Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting(urls) }`
    - Attach `.onDrag { NSItemProvider(...) }`: for `.text` register `.string`, plus `.rtf` and `.html` when the item has those; for `.image(data)` register `.png`; for `.file(urls)` return one provider per URL using `registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, ...)`
    - _Requirements: 12.1, 12.5, 14.1, 14.2, 14.3, 14.6, 17.3, 17.4, 17.7_

  - [ ] 21.2 Lift the preview state into `ClipboardListView` (unified preview)
    - Remove `@State private var isShowingPreview` and the row-local `.popover` from `ClipboardRowView`; replace the Force Touch `onDeepPress` handler with a closure `onRequestPreview: () -> Void` that the list supplies
    - In `ClipboardListView`, add `@State private var isShowingPreview: Bool = false` and `@State private var previewItem: ClipboardItem?`, and pass `onRequestPreview: { previewItem = items[index]; isShowingPreview = true }` into each `ClipboardRowView`
    - Add `.onKeyPress(.space)` at the list level: when `isShowingPreview == false` and a row is focused, set `previewItem = items[focusedIndex]; isShowingPreview = true`; when `isShowingPreview == true`, set `isShowingPreview = false` and return keyboard focus to the originating row
    - Present the preview via a single `.popover(isPresented: $isShowingPreview, arrowEdge: .trailing) { if let previewItem { ClipboardItemPreview(item: previewItem) } }` attached at the list level
    - _Requirements: 13.1, 13.2, 13.4, 13.5, 13.6_

  - [ ] 21.3 Extend `ClipboardItemPreview` for files, rich text, code, and OCR
    - Add a `.file(urls)` branch that shows a 64×64 `NSWorkspace.icon(forFile:)`, the file name as a title, the full `urls[0].path` in a monospaced body row, `FileManager` size and modification-date metadata, and a `Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting(urls) }`
    - For `.text(string)`, when `item.rtfData != nil` decode via `NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)` and render via `AttributedString`; when `rtfData == nil` but `htmlData != nil` decode with `.html`; on decode failure fall back to the plain branch
    - For `.text(string)` without rich variants, call `let verdict = CodeDetector.detect(string)`; if `verdict.isCode`, render `syntaxHighlighter.highlight(string, language: verdict.language)` via `AttributedString`
    - For `.image(data)` when `item.ocrText?.isEmpty == false`, append a `DisclosureGroup("Recognized Text") { Text(item.ocrText!).textSelection(.enabled) }` below the image
    - Inject `syntaxHighlighter: any SyntaxHighlighter` through the initializer (default: `PlainMonospaceHighlighter()`)
    - _Requirements: 9.7, 10.3, 10.4, 13.3, 17.3_

  - [ ] 21.4 Suspend arrow-key navigation while the preview is open
    - In `ClipboardListView`, short-circuit the `.onKeyPress(.upArrow)` and `.onKeyPress(.downArrow)` handlers to `return .ignored` when `isShowingPreview == true`, so focus does not move underneath the preview
    - `Escape` should close the preview first (by flipping `isShowingPreview = false`) and only dismiss the popover when the preview is already closed
    - _Requirements: 13.5_

  - [ ] 21.5 Prevent popover auto-dismiss during drag
    - Add a `DragInFlightMonitor` helper in `ClipboardListView` (or `PopoverView`) that uses `NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged)` on the popover window to observe when a drag begins originating from a row and ends
    - While a drag is in progress, temporarily set `NSPopover.behavior = .applicationDefined` on the enclosing popover; restore the previous behavior (`.transient`) when the drag ends
    - Expose a single hook the view can call to set/restore the behavior via the `StatusBarController`
    - _Requirements: 14.4_

  - [ ]* 21.6 Write unit tests for the extended views
    - **Preview-component-reuse test**: assert that invoking the list-level Space handler and invoking a row's `onRequestPreview` both set the same `(isShowingPreview, previewItem)` state and that the `.popover` presents `ClipboardItemPreview(item: previewItem!)`
    - Assert a `.file([fileURL("README.md")])` row renders the file name and icon view
    - Assert `.onDrag` on a text row with `rtfData` returns an `NSItemProvider` registered for both `.string` and `.rtf`
    - Assert `.onDrag` on an image row returns an `NSItemProvider` registered for `.png`
    - Assert `.onDrag` on a file row returns one `NSItemProvider` per URL for `.fileURL`
    - Assert that pressing Space with the preview open flips `isShowingPreview` to `false`
    - Assert that beginning a drag flips `NSPopover.behavior` to `.applicationDefined` and restores `.transient` on drag end
    - _Requirements: 13.1, 13.2, 13.4, 13.6, 14.1, 14.2, 14.3, 14.4, 14.6, 17.3, 17.4_

- [ ] 22. Build PreferencesView and wire launch-at-login through PreferencesStore
  - [ ] 22.1 Create `PreferencesView`
    - Create `Sources/CopyCat/Views/PreferencesView.swift` with a SwiftUI `Form` divided into sections:
      - **General**: `Toggle("Launch at login", isOn: $preferences.launchAtLogin)` (the `didSet` on `PreferencesStore.launchAtLogin` delegates to `LaunchAtLoginManager.setEnabled(_:)`); `Picker("Default re-copy format", selection: $preferences.defaultRecopyFormat)` with `.rich` and `.plain` cases
      - **Shortcuts**: `KeyboardShortcuts.Recorder("Toggle popover", name: .togglePopover)`
      - **History**: `Picker("History size", selection: $preferences.historyCap)` exposing 50, 200, 500, Unlimited, and a Custom case backed by a `TextField` for a positive integer; `Picker("Age expiry", selection: $preferences.ageExpiryDays)` with Off (nil), 7, 30, 90, and Custom days
      - **Quick Paste**: `Toggle("Auto-paste after Cmd+1…Cmd+9", isOn: $preferences.autoPasteEnabled)` plus a secondary helper `Text("Requires Accessibility permission. You will be prompted the first time you enable this.")` and a `Button("Open Accessibility Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }`
    - _Requirements: 1.5, 10.8, 11.1, 15.1, 15.5, 15.8_

  - [ ] 22.2 Present `PreferencesView` from the `Settings` scene
    - In `Sources/CopyCat/CopyCatApp.swift`, replace `Settings { EmptyView() }` with `Settings { PreferencesView(preferences: appDelegate.preferencesStore, launchAtLogin: appDelegate.launchAtLoginManager) }`
    - _Requirements: 1.5, 11.1_

  - [ ]* 22.3 Write unit tests for PreferencesView
    - Render the view in an `NSHostingView` and assert the expected controls exist (launch-at-login toggle, recorder, both history pickers, auto-paste toggle)
    - Drive `preferences.historyCap = .finite(3)` on a test double that forwards to a mock `HistoryStore.enforceCap`; assert the mock was called with `.finite(3)`
    - _Requirements: 1.5, 10.8, 11.1, 15.1, 15.5, 15.8_

- [ ] 23. Wire everything in AppDelegate
  - [ ] 23.1 Instantiate new services on launch
    - In `AppDelegate.applicationDidFinishLaunching`, instantiate `preferencesStore = PreferencesStore()`, `ocrService = OCRService()`, `autoPasteService = AutoPasteService()`, and `expiryScheduler = ExpiryScheduler()`
    - Replace the `StatusBarController()` init with `StatusBarController(autoPasteService: autoPasteService)` and wire the shared `PreferencesStore` and `AutoPasteService` instances into the popover content
    - _Requirements: 9.1–9.8, 10.1–10.8, 11.1–11.10, 12.1–12.8, 13.1–13.6, 14.1–14.6, 15.1–15.8, 16.1–16.4, 17.1–17.7_

  - [ ] 23.2 Register the global shortcut
    - Call `KeyboardShortcuts.onKeyDown(for: .togglePopover) { [weak self] in self?.statusBarController.togglePopover() }` from `applicationDidFinishLaunching`
    - _Requirements: 11.3_

  - [ ] 23.3 Rewire ClipboardMonitor callbacks into HistoryStore
    - Set `clipboardMonitor.onNewContent = { [weak self] rep in self?.historyStore.addRepresentation(rep) }`
    - Set `clipboardMonitor.onOCRCompleted = { [weak self] id, text in self?.historyStore.applyOCR(text, to: id) }`
    - Start monitoring after the callbacks are assigned
    - _Requirements: 9.3, 9.4, 16.1, 17.2_

  - [ ] 23.4 Observe PreferencesStore for cap and expiry enforcement
    - Using the `@Observable` observation pattern (`withObservationTracking`), react to `preferencesStore.historyCap` by calling `historyStore.enforceCap(_:)` and to `preferencesStore.ageExpiryDays` by calling `historyStore.enforceAgeExpiry(days:)` whenever the value changes
    - Start `expiryScheduler.start(store: historyStore, preferences: preferencesStore)` so it runs once at launch and on an hourly timer
    - _Requirements: 15.7, 15.8_

  - [ ] 23.5 Pass AutoPasteService and PreferencesStore into the popover content
    - Update `PopoverView`'s initializer to accept `preferences: PreferencesStore` and `autoPasteService: AutoPasteService`, and forward them into `ClipboardListView` so the Cmd+1…Cmd+9 handler from task 20.3 can resolve its dependencies
    - Update `AppDelegate`'s `popoverView` construction accordingly
    - _Requirements: 11.8_

  - [ ]* 23.6 Write integration test for the full launch flow
    - In a test that boots `AppDelegate.applicationDidFinishLaunching(_:)` under a hosted `NSApplication`, assert that `statusBarController`, `historyStore`, `clipboardMonitor`, `preferencesStore`, `autoPasteService`, and `expiryScheduler` are all non-nil, and that `KeyboardShortcuts.getShortcut(for: .togglePopover)` is non-nil
    - Smoke test: write a file URL onto an isolated `NSPasteboard` via a fake extractor injection and assert a corresponding `.file` item appears in `historyStore.items`
    - _Requirements: 1.1, 11.3, 17.2_

- [ ] 24. Final checkpoint — All tests pass, including new property tests
  - Run `swift build` and confirm zero warnings / errors across the entire target
  - Run `swift test` and confirm every required test passes, including all newly-added property tests (Properties 10–16) when the optional PBT sub-tasks have been implemented
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation of each layer before moving on
- Property tests validate the 9 universal correctness properties defined in the design document using SwiftCheck
- Unit tests validate specific examples, edge cases, and UI behavior
- The Liquid Glass design skill (`.kiro/skills/liquid-glass-design/SKILL.md`) should be referenced when implementing tasks 8.1–8.4 for correct `.glassEffect()` usage, `GlassEffectContainer` wrapping, and `.interactive()` modifier patterns
- All code is Swift targeting macOS 26, using SwiftUI for views and AppKit for the status bar bridge
- Requirements 9–17 build on top of the baseline without replacing any existing tasks
- The Space-key preview and the Force Touch preview use the same `ClipboardItemPreview` component; there is no separate Quick Look task
- The syntax-highlighting library (Splash vs Sourceful) is deferred; tasks ship a `PlainMonospaceHighlighter` and a `SyntaxHighlighter` protocol so a concrete choice is a small follow-up file
- Property tests 10–16 (optional, marked with `*`) validate the new correctness properties using SwiftCheck with at least 100 iterations each
