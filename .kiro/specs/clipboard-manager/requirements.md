# Requirements Document

## Introduction

CopyCat is a native macOS 26 menu bar clipboard manager built with SwiftUI and the Liquid Glass design language. The app provides a persistent menu bar icon (NSStatusItem) that opens a popover displaying clipboard history — text, image, and file items. Users can tap any saved item to re-copy it to the system clipboard without creating a duplicate entry in the history list. The app runs exclusively in the menu bar and does not appear in the Dock.

Beyond the baseline clipboard behavior (Requirements 1–8), this document also specifies an extended feature set (Requirements 9–17): on-device OCR for images, rich/formatted content preservation and optional syntax highlighting for code, a user-customizable global shortcut with quick-paste number shortcuts, pinned items, Quick Look previews, drag-out support, configurable history size and age-based expiry, smart duplicate handling, and file URL support.

**Open design questions for the extended feature set**:

- **Syntax highlighting library** (Requirement 10): Not yet chosen. Splash and Sourceful are both under consideration. Requirements are written to be library-agnostic — they specify the capability (syntax highlighting for code), not the implementation.

## Glossary

- **App**: The CopyCat macOS 26 menu bar clipboard manager application
- **Menu_Bar_Icon**: The persistent NSStatusItem icon displayed in the macOS menu bar that serves as the entry point to the App
- **Popover**: The panel that appears when the user clicks the Menu_Bar_Icon, displaying the clipboard history
- **Clipboard_History**: The ordered list of previously copied items maintained by the App
- **Clipboard_Item**: A single entry in the Clipboard_History, containing text, image, or file content
- **System_Clipboard**: The macOS system pasteboard (NSPasteboard.general) used for copy/paste operations
- **Clipboard_Monitor**: The background service that observes the System_Clipboard for new content
- **Liquid_Glass**: The macOS 26 design language featuring dynamic glass material with blur, reflection, and interactive morphing
- **OCR_Engine**: The on-device text recognition subsystem backed by Apple's Vision framework (VNRecognizeTextRequest)
- **OCR_Text**: The text string extracted from an image Clipboard_Item by the OCR_Engine
- **Rich_Clipboard_Content**: Formatted pasteboard variants (e.g. RTF, HTML) captured alongside plain text when present on the System_Clipboard
- **Syntax_Highlighter**: The component that applies colored tokenization to plain source-code text when no Rich_Clipboard_Content is available; specific library is TBD (Splash or Sourceful)
- **Pinned_Item**: A Clipboard_Item the user has explicitly pinned; exempt from the History_Cap and Age_Expiry, and sorted above non-pinned items
- **Preferences**: The user-visible configuration surface of the App, exposing settings such as the global shortcut, History_Cap, Age_Expiry, Auto_Paste, and default re-copy format
- **Quick_Paste_Shortcut**: One of the Cmd+1 through Cmd+9 keyboard shortcuts that, while the Popover is open, re-copies the filtered Clipboard_Item at the corresponding 1-indexed position
- **Auto_Paste**: The opt-in behavior that, after a Quick_Paste_Shortcut re-copy, dismisses the Popover, reactivates the previously focused application, and synthesizes a Cmd+V paste event; requires macOS Accessibility permission
- **Detail_Preview**: The expanded preview panel that renders a single Clipboard_Item with its full content and metadata; reached either by a Force Touch deep press on a row or by pressing the Space key while a row is focused. This is the one and only preview surface — there is no separate Quick Look panel.
- **History_Cap**: The user-configurable maximum number of non-pinned Clipboard_Items retained in the Clipboard_History
- **Age_Expiry**: The user-configurable policy that automatically removes non-pinned Clipboard_Items whose age exceeds a configured duration in days
- **File_Item**: A Clipboard_Item whose content is one or more file URLs captured from the `public.file-url` / NSPasteboardTypeFileURL pasteboard type
- **Drag_Operation**: A user-initiated drag gesture that carries a Clipboard_Item's content out of the Popover onto another application

## Requirements

### Requirement 1: Menu Bar Presence

**User Story:** As a user, I want the app to display a persistent icon in the macOS menu bar, so that I can quickly access my clipboard history at any time.

#### Acceptance Criteria

1. THE App SHALL display a Menu_Bar_Icon in the macOS menu bar when the App is running
2. THE App SHALL run as a menu bar-only application without displaying a Dock icon
3. WHEN the user clicks the Menu_Bar_Icon, THE App SHALL display the Popover below the Menu_Bar_Icon
4. WHEN the Popover is open and the user clicks outside the Popover, THE App SHALL dismiss the Popover
5. THE App SHALL launch at login if the user has enabled the launch-at-login preference

### Requirement 2: Clipboard Monitoring

**User Story:** As a user, I want the app to automatically detect when I copy text or images, so that my clipboard history is built without manual effort.

#### Acceptance Criteria

1. WHILE the App is running, THE Clipboard_Monitor SHALL poll the System_Clipboard for changes at an interval of no more than 1 second
2. WHEN the Clipboard_Monitor detects new text content on the System_Clipboard, THE App SHALL create a new Clipboard_Item of type text and prepend it to the Clipboard_History
3. WHEN the Clipboard_Monitor detects new image content on the System_Clipboard, THE App SHALL create a new Clipboard_Item of type image and prepend it to the Clipboard_History
4. WHEN the Clipboard_Monitor detects content that is identical to the most recent Clipboard_Item, THE App SHALL discard the duplicate and retain the existing entry
5. WHEN the App itself writes an item to the System_Clipboard (via re-copy), THE Clipboard_Monitor SHALL ignore that change and not create a new Clipboard_Item

### Requirement 3: Clipboard History Display

**User Story:** As a user, I want to see my clipboard history in a scrollable list, so that I can browse and find previously copied items.

#### Acceptance Criteria

1. WHEN the Popover is displayed, THE App SHALL show the Clipboard_History as a vertically scrollable list with the most recent Clipboard_Item at the top
2. THE App SHALL display text Clipboard_Items as a single-line preview truncated to 80 characters with an ellipsis
3. THE App SHALL display image Clipboard_Items as a thumbnail preview with a maximum height of 60 points
4. THE App SHALL display a timestamp relative to the current time (e.g., "2 min ago") for each Clipboard_Item
5. THE App SHALL apply the Liquid_Glass design language to the Popover container and interactive list items
6. WHEN the Clipboard_History is empty, THE App SHALL display a placeholder message indicating no items have been copied

### Requirement 4: Re-Copy to Clipboard

**User Story:** As a user, I want to tap a previously copied item to make it the current clipboard content, so that I can paste it again without searching for the original source.

#### Acceptance Criteria

1. WHEN the user clicks a Clipboard_Item in the Popover, THE App SHALL write that Clipboard_Item's content to the System_Clipboard
2. WHEN the user clicks a Clipboard_Item in the Popover, THE App SHALL dismiss the Popover
3. WHEN the user re-copies a Clipboard_Item, THE App SHALL retain the Clipboard_Item at its current position in the Clipboard_History without moving or duplicating it
4. WHEN the user re-copies a Clipboard_Item, THE App SHALL provide brief visual feedback (highlight animation) before dismissing the Popover

### Requirement 5: Clipboard Item Management

**User Story:** As a user, I want to delete individual items or clear my entire clipboard history, so that I can manage sensitive or outdated content.

#### Acceptance Criteria

1. WHEN the user right-clicks a Clipboard_Item, THE App SHALL display a context menu with a "Delete" option
2. WHEN the user selects "Delete" from the context menu, THE App SHALL remove that Clipboard_Item from the Clipboard_History
3. THE App SHALL provide a "Clear All" button in the Popover that removes all items from the Clipboard_History
4. WHEN the user clicks "Clear All", THE App SHALL display a confirmation prompt before removing all items

### Requirement 6: History Persistence

**User Story:** As a user, I want my clipboard history to persist across app restarts, so that I don't lose previously copied items.

#### Acceptance Criteria

1. THE App SHALL persist the Clipboard_History to local storage when a new Clipboard_Item is added or removed
2. WHEN the App launches, THE App SHALL restore the Clipboard_History from local storage
3. THE App SHALL store a maximum of 50 Clipboard_Items in the Clipboard_History
4. WHEN the Clipboard_History reaches 50 items and a new item is added, THE App SHALL remove the oldest Clipboard_Item to make room for the new one
5. THE App SHALL serialize text Clipboard_Items as UTF-8 strings and image Clipboard_Items as PNG data for storage
6. FOR ALL valid Clipboard_Items, serializing then deserializing a Clipboard_Item SHALL produce an equivalent Clipboard_Item (round-trip property)

### Requirement 7: Search and Filter

**User Story:** As a user, I want to search through my clipboard history, so that I can quickly find a specific item without scrolling.

#### Acceptance Criteria

1. THE App SHALL display a search field at the top of the Popover
2. WHEN the user types in the search field, THE App SHALL filter the Clipboard_History to show only text Clipboard_Items whose content contains the search query (case-insensitive)
3. WHEN the search query is cleared, THE App SHALL display the full Clipboard_History
4. WHILE a search filter is active, THE App SHALL display the count of matching items

### Requirement 8: Keyboard Navigation

**User Story:** As a user, I want to navigate and select clipboard items using keyboard shortcuts, so that I can work efficiently without reaching for the mouse.

#### Acceptance Criteria

1. THE App SHALL register a global keyboard shortcut (Cmd+Shift+V) to toggle the Popover
2. WHILE the Popover is open, THE App SHALL support arrow key navigation through the Clipboard_History list
3. WHILE the Popover is open and a Clipboard_Item is highlighted, WHEN the user presses Enter, THE App SHALL re-copy the highlighted Clipboard_Item to the System_Clipboard
4. WHILE the Popover is open, WHEN the user presses Escape, THE App SHALL dismiss the Popover

### Requirement 9: On-Device OCR for Image Items

**User Story:** As a user, I want the text inside screenshots and other copied images to be recognized and searchable, so that I can find an image by typing text that appears in it.

#### Acceptance Criteria

1. THE OCR_Engine SHALL use Apple's Vision framework VNRecognizeTextRequest exclusively for text recognition, with no external network dependencies
2. THE OCR_Engine SHALL support at least 8 of the languages exposed by VNRecognizeTextRequest.supportedRecognitionLanguages on the host system
3. WHEN an image Clipboard_Item is added to the Clipboard_History, THE App SHALL schedule OCR extraction for that item either asynchronously at capture time or lazily on the first time the item's preview is displayed
4. WHEN OCR extraction for an image Clipboard_Item completes successfully, THE App SHALL store the resulting OCR_Text on the Clipboard_Item
5. THE App SHALL persist the OCR_Text as part of the Clipboard_Item so that the OCR_Text is available after an App restart without recomputation
6. WHILE a search query is active, THE App SHALL include image Clipboard_Items whose OCR_Text contains the search query case-insensitively in the filtered results
7. WHEN the user views the preview of an image Clipboard_Item that has a non-empty OCR_Text, THE App SHALL display the OCR_Text alongside the image
8. IF OCR extraction fails for an image Clipboard_Item, THEN THE App SHALL record an empty OCR_Text for that item, log a warning, and continue operating without blocking the Clipboard_History

### Requirement 10: Rich Content Preservation and Code Formatting in Preview

**User Story:** As a developer, I want copied code and other formatted text to retain its colors and formatting in the preview, so that I can visually recognize snippets and recopy them without losing their appearance.

#### Acceptance Criteria

1. WHEN the Clipboard_Monitor detects new content on the System_Clipboard, THE App SHALL capture the RTF pasteboard variant when present and store it on the Clipboard_Item alongside the plain text
2. WHEN the Clipboard_Monitor detects new content on the System_Clipboard, THE App SHALL capture the HTML pasteboard variant when present and store it on the Clipboard_Item alongside the plain text
3. WHEN the preview for a text Clipboard_Item is displayed and the Clipboard_Item has Rich_Clipboard_Content, THE App SHALL render the preview using NSAttributedString derived from the Rich_Clipboard_Content
4. WHERE a text Clipboard_Item has no Rich_Clipboard_Content and the plain text is detected as source code, THE Syntax_Highlighter SHALL produce an NSAttributedString that the App renders as the preview
5. THE App SHALL select the Syntax_Highlighter implementation from a single library chosen during design; the library selection between Splash and Sourceful is TBD at requirements time and the specification is library-agnostic
6. WHEN the user re-copies a Clipboard_Item that has Rich_Clipboard_Content, THE App SHALL write both the Rich_Clipboard_Content and the plain text representation back to the System_Clipboard by default
7. WHERE the user invokes the plain-text re-copy path, either via a modifier key during click or via a default-format Preferences setting, THE App SHALL write only the plain text representation to the System_Clipboard and omit the Rich_Clipboard_Content
8. THE App SHALL expose a Preferences toggle that selects the default re-copy format between rich-preserving and plain-text-only, and SHALL persist that selection across launches

### Requirement 11: Customizable Global Shortcut and Quick Paste

**User Story:** As a user, I want to change the global shortcut that opens the clipboard popover and to quickly re-copy the first nine items using number keys, so that I can make CopyCat fit my muscle memory and paste common items without clicking.

#### Acceptance Criteria

1. THE App SHALL expose a Preferences control that captures a user-defined key combination for the global Popover toggle shortcut
2. THE App SHALL persist the user-defined global shortcut across App launches
3. WHEN the App launches, THE App SHALL register the persisted global shortcut; when no user-defined shortcut has been saved, THE App SHALL register Cmd+Shift+V as the default
4. IF the user-defined shortcut conflicts with a shortcut already reserved by macOS, THEN THE App SHALL reject the assignment and display a message explaining the conflict
5. WHILE the Popover is open, WHEN the user presses one of Cmd+1 through Cmd+9, THE App SHALL treat the digit as a 1-indexed position into the currently filtered Clipboard_History and re-copy the Clipboard_Item at that position to the System_Clipboard
6. IF the user presses a Quick_Paste_Shortcut whose index exceeds the number of currently filtered items, THEN THE App SHALL ignore the keystroke and leave the Popover state unchanged
7. THE App SHALL expose a Preferences toggle named Auto_Paste that controls synthetic-paste behavior, defaulting to off
8. WHERE Auto_Paste is enabled, WHEN the user triggers a Quick_Paste_Shortcut, THE App SHALL dismiss the Popover, reactivate the previously focused application, and synthesize a Cmd+V key event to that application
9. WHERE Auto_Paste is enabled AND macOS Accessibility permission has not been granted to the App, THE App SHALL prompt the user to grant Accessibility permission before synthesizing the Cmd+V event
10. IF Accessibility permission is denied while Auto_Paste is enabled, THEN THE App SHALL still perform the re-copy, skip the synthetic paste, and display a message explaining that Accessibility is required for auto-paste

### Requirement 12: Pinned Items

**User Story:** As a user, I want to pin important clipboard items, so that they stay accessible even as new items push older ones out of history.

#### Acceptance Criteria

1. THE App SHALL provide a "Pin" action in the context menu of any non-pinned Clipboard_Item and an "Unpin" action in the context menu of any Pinned_Item
2. WHEN the user invokes the Pin action on a Clipboard_Item, THE App SHALL mark that Clipboard_Item as a Pinned_Item and persist the pinned state
3. WHEN the user invokes the Unpin action on a Pinned_Item, THE App SHALL remove the pinned state from that Clipboard_Item and persist the change
4. THE App SHALL sort Pinned_Items above non-pinned Clipboard_Items in the Popover list, with Pinned_Items ordered among themselves by `createdAt` descending
5. THE App SHALL display a visible pin indicator on each Pinned_Item row in the Popover
6. WHEN the App enforces the History_Cap, THE App SHALL exclude Pinned_Items from the count against the History_Cap and SHALL NOT evict Pinned_Items to make room for new items
7. WHEN the App applies Age_Expiry, THE App SHALL exclude Pinned_Items from removal regardless of their age
8. THE App SHALL persist the pinned state of each Clipboard_Item across App launches

### Requirement 13: Space-Key Preview

**User Story:** As a user, I want to press Space on a focused clipboard item to open the same detailed preview I can already reach with a Force Touch deep press, so that I can inspect full content from the keyboard without re-copying and without learning a second preview UI.

#### Acceptance Criteria

1. WHILE the Popover is open and a Clipboard_Item row has keyboard focus, WHEN the user presses the Space key, THE App SHALL present the Detail_Preview for the focused Clipboard_Item
2. THE Detail_Preview presented via the Space key SHALL be the same Detail_Preview component presented by a Force Touch deep press on a row, rendered with identical content, layout, and metadata
3. THE Detail_Preview SHALL render text Clipboard_Items with their full text selectable, image Clipboard_Items at full resolution with dimension and data-size metadata, and File_Items with the file icon, file name, and path
4. WHILE the Detail_Preview is open, WHEN the user presses the Space key or the Escape key, THE App SHALL dismiss the Detail_Preview and return keyboard focus to the originating row in the Popover
5. WHILE the Detail_Preview is open, arrow-key navigation in the Popover SHALL remain suspended until the Detail_Preview is dismissed
6. THE App SHALL NOT introduce a separate Quick Look panel distinct from the Detail_Preview; Space and Force Touch deep press are two entry points to the same preview surface

### Requirement 14: Drag Items Out of the Popover

**User Story:** As a user, I want to drag clipboard items directly from the popover into other applications, so that I can transfer content without going through copy and paste.

#### Acceptance Criteria

1. WHEN the user initiates a Drag_Operation on a text Clipboard_Item row, THE App SHALL provide the Clipboard_Item's plain text as the drag payload using the standard string pasteboard type
2. WHEN the user initiates a Drag_Operation on an image Clipboard_Item row, THE App SHALL provide the Clipboard_Item's image data as the drag payload using a standard image pasteboard type
3. WHEN the user initiates a Drag_Operation on a File_Item row, THE App SHALL provide the File_Item's file URLs as the drag payload using the file URL pasteboard type
4. WHILE a Drag_Operation that originated in the Popover is in progress, THE App SHALL keep the Popover visible and SHALL NOT auto-dismiss it on focus changes
5. WHEN a Drag_Operation originating in the Popover completes, THE App SHALL leave the Clipboard_History unchanged
6. WHEN the user drags a text Clipboard_Item row that has Rich_Clipboard_Content, THE App SHALL include both the Rich_Clipboard_Content and the plain text representation in the drag payload

### Requirement 15: Configurable History Size and Age-Based Expiry

**User Story:** As a user, I want to configure how many items the app keeps and to optionally expire items after a number of days, so that history size matches my workflow and privacy preferences.

#### Acceptance Criteria

1. THE App SHALL expose a Preferences control that sets the History_Cap with at least the choices 50, 200, 500, unlimited, and a custom positive integer
2. THE App SHALL persist the History_Cap across App launches and SHALL use 50 as the default History_Cap when no value has been persisted
3. WHEN a new non-pinned Clipboard_Item is added and the count of non-pinned Clipboard_Items exceeds the History_Cap, THE App SHALL evict the oldest non-pinned Clipboard_Items until the count equals the History_Cap
4. WHERE the History_Cap is set to unlimited, THE App SHALL NOT evict Clipboard_Items on size grounds
5. THE App SHALL expose a Preferences control that sets the Age_Expiry, with at least the choices off and a custom positive integer number of days
6. THE App SHALL persist the Age_Expiry across App launches and SHALL use off as the default Age_Expiry when no value has been persisted
7. WHERE the Age_Expiry is set to a positive number of days N, THE App SHALL remove any non-pinned Clipboard_Item whose `createdAt` is older than N days from the current date
8. WHEN the user changes the History_Cap or Age_Expiry in Preferences, THE App SHALL apply the new setting immediately, pruning Clipboard_Items as needed, and persist the new setting

### Requirement 16: Smart Duplicate Handling

**User Story:** As a user, I want copying a value I already had in history to move the existing entry to the top instead of creating a duplicate, so that my history does not fill up with repeats of the same content.

#### Acceptance Criteria

1. WHEN the Clipboard_Monitor detects content that equals the content of an existing non-pinned Clipboard_Item at any position in the Clipboard_History, THE App SHALL move that existing Clipboard_Item to the top of the Clipboard_History and update its `createdAt` to the current time, without creating a new Clipboard_Item
2. WHEN a Clipboard_Item is moved to the top under this deduplication behavior, THE total count of Clipboard_Items in the Clipboard_History SHALL remain unchanged
3. WHEN the Clipboard_Monitor detects content that equals the content of an existing Pinned_Item, THE App SHALL leave the Pinned_Item in its pinned position and SHALL still apply duplicate detection against existing non-pinned items so that no new non-pinned duplicate Clipboard_Item is created
4. IF the detected content does not match any existing Clipboard_Item, THEN THE App SHALL create a new Clipboard_Item and prepend it to the Clipboard_History as specified in Requirement 2

### Requirement 17: File Reference Clipboard Items

**User Story:** As a user, I want the clipboard manager to capture files I copy in Finder, so that I can re-copy file references and paste them elsewhere just like text or images.

#### Acceptance Criteria

1. THE App SHALL extend ClipboardItemContent with a file case that carries one or more file URLs
2. WHEN the Clipboard_Monitor detects content on the System_Clipboard that exposes the `public.file-url` / NSPasteboardTypeFileURL type, THE App SHALL create a File_Item whose content is the list of file URLs present on the System_Clipboard
3. THE App SHALL display each File_Item in the Popover list with the file's icon obtained via NSWorkspace and with the file's display name
4. WHERE a File_Item contains more than one file URL, THE App SHALL display a single row showing the icon of the first file and a label that indicates the total number of files
5. WHEN the user re-copies a File_Item, THE App SHALL write the File_Item's file URLs to the System_Clipboard using the file URL pasteboard type so that subsequent paste operations in Finder produce a file paste
6. THE App SHALL persist File_Items as the list of file URL strings and SHALL restore them on App launch without copying or duplicating the underlying files
7. IF a File_Item references a file URL that no longer resolves to an existing file at the time of display or re-copy, THEN THE App SHALL indicate the stale state visually on the row and SHALL still permit the re-copy of the original URL
