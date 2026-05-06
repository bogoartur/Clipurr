# 🐾 Clipurr

Clipurr is a personal, lightweight clipboard manager built specifically for macOS. It runs quietly in the background, keeping an easily accessible history of your copied text, images, and files so you never lose track of your recent snippets.

## Features
* **Text, Image & File History:** Captures copied text (with optional rich RTF/HTML variants), images, and file references from Finder.
* **On-Device OCR:** Screenshots become searchable — text inside images is recognized via Apple's Vision framework.
* **Smart Dedup & Pinned Items:** Re-copying existing content promotes it to the top instead of duplicating; pin anything to keep it safe from eviction.
* **Mac-Native Workflow:** Designed specifically for macOS 26 with Liquid Glass styling, Force Touch preview, and a customizable global shortcut.
* **Local & Private:** 100% self-use and locally hosted. Your clipboard data never leaves your machine.

## Getting Started

1. Clone the repository to your local machine.
2. Open the project in Xcode 26 (or run `swift build` from the terminal to resolve dependencies and compile).
3. Build and run the project.

Preferences open with `Cmd+,` and let you rebind the global shortcut, set the history cap, enable age-based expiry, pick the default re-copy format (rich vs plain), and toggle auto-paste for the Cmd+1…Cmd+9 quick-paste shortcuts.
