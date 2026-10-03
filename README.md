# Clipurr

A native macOS clipboard-history utility built with SwiftUI and AppKit.

**[Open the implementation and source code](https://github.com/bogoartur/Clipurr/tree/feat/clipboard-manager-implementation)**. The implementation currently lives on `feat/clipboard-manager-implementation`; `main` is the project landing page.

## Implemented workflow

Clipboard capture → deduplication and local JSON storage → search (including Apple Vision OCR) → re-copy.

- Text, images and Finder file references; optional RTF/HTML text representations.
- Pinning, configurable history cap and optional age expiry. Pins survive automatic eviction, but explicit deletion still removes them.
- Rich/plain re-copy, global shortcut, Cmd+1 through Cmd+9 quick re-copy and optional auto-paste.

## Build from source

Requires **macOS 26, Swift 6.2 and full Xcode 26 with the macOS 26 SDK**. Command Line Tools alone are insufficient for the current dependencies.

```sh
git clone --branch feat/clipboard-manager-implementation https://github.com/bogoartur/Clipurr.git
cd Clipurr
swift build
swift test
swift run Clipurr
```

On October 3, 2026, dependency resolution completed, but `swift build` stopped in KeyboardShortcuts because the Command Line Tools installation lacks `PreviewsMacros`; `swift test` stopped because XCTest is unavailable. App launch and end-to-end behavior remain unverified in this pass. No signed release is published.

## Storage and permissions

History is written to `~/Library/Application Support/Clipurr/history.json`; OCR uses Apple Vision. The app does not encrypt the history file. There are no per-app exclusions or secret-detection filters. Optional auto-paste uses Accessibility permission to send Cmd+V. Launch-at-login and packaged-app behavior still need verification with a proper app bundle.

## Source map

- `Sources/Clipurr/Domain`: monitoring, extraction, storage, OCR and preferences.
- `Sources/Clipurr/AppKit`: menu-bar popover and application wiring.
- `Sources/Clipurr/Views`: list, search, preview and settings.
- `Tests/ClipurrTests`: serialization and history-store tests.

## Em português

Utilitário nativo de histórico da área de transferência para macOS 26. Captura textos, imagens e referências de arquivos, com busca, OCR local, deduplicação e itens fixados. O código está na branch de implementação acima. Projeto em desenvolvimento: build, testes e comportamento completo precisam ser verificados com Xcode 26 antes de uma versão pública.

[Portfolio](https://www.arturbogo.dev/) · [Artur Bogo](https://www.linkedin.com/in/arturbogo/)
