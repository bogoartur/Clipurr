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

  - [ ]* 1.3 Write property test for serialization round-trip
    - **Property 8: Serialization round-trip**
    - Implement `Arbitrary` conformance for `ClipboardItemContent` and `ClipboardItem` using SwiftCheck
    - Verify that encoding a `ClipboardItem` to JSON and decoding it back produces an equal item
    - Run a minimum of 100 iterations
    - **Validates: Requirements 6.5, 6.6**

  - [ ]* 1.4 Write property test for text preview truncation
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

  - [ ]* 2.2 Write unit tests for PersistenceManager
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

  - [ ]* 3.2 Write property test for content prepend
    - **Property 1: Content prepend**
    - For any valid clipboard content added to a non-duplicate history, verify the new item appears at index 0 and history length increases by exactly one
    - Run a minimum of 100 iterations
    - **Validates: Requirements 2.2, 2.3**

  - [ ]* 3.3 Write property test for duplicate discard
    - **Property 2: Duplicate discard**
    - For any content identical to the most recent item, verify the history remains completely unchanged after the add attempt
    - Run a minimum of 100 iterations
    - **Validates: Requirements 2.4**

  - [ ]* 3.4 Write property test for newest-first ordering invariant
    - **Property 3: Newest-first ordering invariant**
    - For any sequence of add and delete operations, verify the resulting list is always ordered by `createdAt` descending
    - Run a minimum of 100 iterations
    - **Validates: Requirements 3.1**

  - [ ]* 3.5 Write property test for re-copy preserves history
    - **Property 5: Re-copy preserves history**
    - For any history and any item within it, verify that re-copy does not change the history list, order, or content
    - Run a minimum of 100 iterations
    - **Validates: Requirements 4.3**

  - [ ]* 3.6 Write property test for delete removes exactly one item
    - **Property 6: Delete removes exactly one item**
    - For any non-empty history and any item within it, verify deletion reduces length by one, the item is gone, and all other items remain in order
    - Run a minimum of 100 iterations
    - **Validates: Requirements 5.2**

  - [ ]* 3.7 Write property test for history cap with eviction
    - **Property 7: History cap with eviction**
    - For any history (including full 50-item histories), verify that after adding a non-duplicate item the length is at most 50, the new item is at index 0, and the oldest item was evicted if at capacity
    - Run a minimum of 100 iterations
    - **Validates: Requirements 6.3, 6.4**

  - [ ]* 3.8 Write property test for search filter correctness
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

  - [ ]* 5.2 Write unit tests for ClipboardMonitor
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

  - [ ]* 8.5 Write unit tests for SwiftUI views
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

  - [ ]* 9.3 Write integration tests
    - Test persistence round-trip: save history to disk, load it back, verify equality
    - Test global keyboard shortcut registration
    - Test launch-at-login preference registration
    - _Requirements: 6.1, 8.1, 1.5_

- [x] 10. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation of each layer before moving on
- Property tests validate the 9 universal correctness properties defined in the design document using SwiftCheck
- Unit tests validate specific examples, edge cases, and UI behavior
- The Liquid Glass design skill (`.kiro/skills/liquid-glass-design/SKILL.md`) should be referenced when implementing tasks 8.1–8.4 for correct `.glassEffect()` usage, `GlassEffectContainer` wrapping, and `.interactive()` modifier patterns
- All code is Swift targeting macOS 26, using SwiftUI for views and AppKit for the status bar bridge
