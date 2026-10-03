# Clipurr

A native macOS clipboard-history utility built with SwiftUI and AppKit.

**[Open the implementation and source code](https://github.com/bogoartur/Clipurr/tree/feat/clipboard-manager-implementation)**. The implementation currently lives on `feat/clipboard-manager-implementation`; `main` is the project landing page.

## Implemented workflow

Clipboard capture → deduplication and local JSON storage → search (including Apple Vision OCR) → re-copy.

- Text, images and Finder file references; optional RTF/HTML text representations.
- Pinning, configurable history cap and optional age expiry. Pins survive automatic eviction, but explicit deletion still removes them.
- Rich/plain re-copy, global shortcut, Cmd+1 through Cmd+9 quick re-copy and optional auto-paste.

## Build from source

Requires **macOS 26, Swift 6.2 and full Xcode 26 or newer with a compatible macOS SDK**. Command Line Tools alone are insufficient for the current dependencies.

```sh
git clone --branch feat/clipboard-manager-implementation https://github.com/bogoartur/Clipurr.git
cd Clipurr
swift build
swift test
swift run Clipurr
```

Verified on October 3, 2026 with full Xcode: debug/release builds, 36 Swift Testing tests, and the XCTest serialization property test pass. Coverage includes rich/plain re-copy on a private pasteboard, pin retention, persistence and real Apple Vision OCR. A temporary app bundle was launched and image search was verified in the native interface. No signed release is published.

For synthetic sample content without monitoring the system clipboard:

```sh
swift run Clipurr --demo
```

Demo history uses a separate temporary directory. `CLIPURR_DATA_DIRECTORY` can also select a disposable storage directory for tests. Demo mode still permits manual re-copy; avoid clicking items if you want to preserve the system clipboard.


## Storage and permissions

History is written to `~/Library/Application Support/Clipurr/history.json`; OCR uses Apple Vision. The app does not encrypt the history file. There are no per-app exclusions or secret-detection filters. Optional auto-paste uses Accessibility permission to send Cmd+V. Launch-at-login and auto-paste still need end-to-end verification; they were not enabled during the demo.

## Source map

- `Sources/Clipurr/Domain`: monitoring, extraction, storage, OCR and preferences.
- `Sources/Clipurr/AppKit`: menu-bar popover and application wiring.
- `Sources/Clipurr/Views`: list, search, preview and settings.
- `Tests/ClipurrTests`: serialization and history-store tests.

## Em português

Utilitário nativo de histórico da área de transferência para macOS 26. Captura textos, imagens e referências de arquivos, com busca, OCR local, deduplicação e itens fixados. O código está na branch de implementação acima. Projeto em desenvolvimento: build e testes passaram com Xcode completo, e a busca por OCR foi verificada no app nativo. Ainda não há versão assinada publicada.

[Portfolio](https://www.arturbogo.dev/) · [Artur Bogo](https://www.linkedin.com/in/arturbogo/)
