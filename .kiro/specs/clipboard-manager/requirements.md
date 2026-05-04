# Requirements Document

## Introduction

CopyCat is a native macOS 26 menu bar clipboard manager built with SwiftUI and the Liquid Glass design language. The app provides a persistent menu bar icon (NSStatusItem) that opens a popover displaying clipboard history — both text and image items. Users can tap any saved item to re-copy it to the system clipboard without creating a duplicate entry in the history list. The app runs exclusively in the menu bar and does not appear in the Dock.

## Glossary

- **App**: The CopyCat macOS 26 menu bar clipboard manager application
- **Menu_Bar_Icon**: The persistent NSStatusItem icon displayed in the macOS menu bar that serves as the entry point to the App
- **Popover**: The panel that appears when the user clicks the Menu_Bar_Icon, displaying the clipboard history
- **Clipboard_History**: The ordered list of previously copied items maintained by the App
- **Clipboard_Item**: A single entry in the Clipboard_History, containing either text or image content
- **System_Clipboard**: The macOS system pasteboard (NSPasteboard.general) used for copy/paste operations
- **Clipboard_Monitor**: The background service that observes the System_Clipboard for new content
- **Liquid_Glass**: The macOS 26 design language featuring dynamic glass material with blur, reflection, and interactive morphing

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
