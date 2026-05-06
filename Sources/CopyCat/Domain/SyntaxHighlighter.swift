// SyntaxHighlighter.swift
// CopyCat
//
// Library-agnostic syntax-highlighting surface.
//
// NOTE: The concrete syntax-highlighting library choice — [Splash]
// (https://github.com/JohnSundell/Splash) vs
// [Sourceful](https://github.com/louisdh/sourceful) vs another — is
// deliberately deferred. Callers (e.g. `ClipboardItemPreview`) depend only
// on the `SyntaxHighlighter` protocol below, not on any concrete library.
//
// To add a concrete highlighter later:
//   1. Add the chosen package to `Package.swift`.
//   2. Create a single adapter file beside this one (e.g.
//      `SplashSyntaxHighlighter.swift` or `SourcefulSyntaxHighlighter.swift`)
//      that conforms to `SyntaxHighlighter`.
//   3. Swap the injected instance at the call site (typically in
//      `AppDelegate` when constructing the popover content).
// No view code should import the concrete library.

import Foundation
import AppKit

// MARK: - SyntaxHighlighter

/// Produces an `NSAttributedString` representation of a source-code string,
/// optionally hinted with a language name.
///
/// Implementations are expected to be stateless and safe to call from any
/// actor context.
protocol SyntaxHighlighter {
    /// Highlights `source` using the conventions for the given `language`.
    ///
    /// - Parameters:
    ///   - source: Raw source code.
    ///   - language: A language hint such as `"swift"`, `"python"`,
    ///     `"javascript"`, `"json"`. When `nil`, the implementation may
    ///     attempt its own detection or fall back to a plain rendering.
    /// - Returns: An attributed string suitable for display in a SwiftUI
    ///   `Text` via `AttributedString` or in an `NSTextView`.
    func highlight(_ source: String, language: String?) -> NSAttributedString
}

// MARK: - PlainMonospaceHighlighter

/// Default `SyntaxHighlighter` that performs no tokenization — it returns
/// the source text wrapped in a monospaced system font.
///
/// This is the fallback that ships until a concrete library is chosen (see
/// the NOTE at the top of this file). Using the fallback keeps the
/// `ClipboardItemPreview` code paths exercised without pulling in a
/// highlighting dependency prematurely.
struct PlainMonospaceHighlighter: SyntaxHighlighter {

    /// Font size applied to the monospaced output. Kept in sync with the
    /// inline code rendering used by `ClipboardItemPreview`.
    var fontSize: CGFloat = 12

    func highlight(_ source: String, language: String?) -> NSAttributedString {
        _ = language // intentionally ignored — the fallback is language-agnostic
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]
        return NSAttributedString(string: source, attributes: attributes)
    }
}
