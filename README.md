# Clipurr

A native macOS clipboard-history utility built with SwiftUI and AppKit.

**[Open the implementation and source code](https://github.com/bogoartur/Clipurr/tree/feat/clipboard-manager-implementation)** - the implementation is currently on `feat/clipboard-manager-implementation`; `main` is this landing page.

## What is implemented

- Text, image and file-reference capture from the system clipboard.
- Search across text and image text recognized with Apple Vision.
- Deduplication, pinned items, configurable history limits and optional age expiry.
- Rich/plain re-copy, a customizable shortcut and optional quick-paste.

## Build from source

Requires macOS 26 and a Swift 6.2 toolchain with the macOS 26 SDK. Full Xcode is required for XCTest-based tests.

```sh
git clone --branch feat/clipboard-manager-implementation https://github.com/bogoartur/Clipurr.git
cd Clipurr
swift build
swift test
swift run Clipurr
```

Build verification is still in progress. On October 3, 2026, the test attempt with Command Line Tools stopped because XCTest was unavailable. No signed release or verified app preview is available yet.

## Storage and permissions

History is written locally to `~/Library/Application Support/Clipurr/history.json`. OCR uses Apple Vision. The JSON history is not encrypted by the app; local storage is not protection against another process with access to that file. No per-app exclusions or secret detection are implemented. Pinned items survive automatic cap/age eviction, but can still be explicitly deleted. Optional auto-paste requires Accessibility permission.

## Em português

Utilitário nativo de histórico da área de transferência para macOS. O código está na branch de implementação acima: captura textos, imagens e referências de arquivos, com busca, OCR local, favoritos e limites de retenção. Projeto em desenvolvimento, sem versão assinada publicada.

[Portfolio](https://www.arturbogo.dev/) · [Artur Bogo](https://www.linkedin.com/in/arturbogo/)
