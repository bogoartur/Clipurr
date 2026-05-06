// CodeDetector.swift
// CopyCat
//
// Heuristic code detector used when a plain-text clipboard item has no
// Rich_Clipboard_Content (RTF/HTML). When the verdict is "code", the
// preview pipeline feeds the source into the injected `SyntaxHighlighter`.
//
// The detector is intentionally small and dependency-free: brace and
// semicolon density, shebang detection, and per-language keyword scoring
// combined against a threshold.

import Foundation

// MARK: - CodeDetector

enum CodeDetector {

    /// Verdict produced by `detect(_:)`.
    struct Verdict: Equatable {
        let isCode: Bool
        /// Language hint, e.g. `"swift"`, `"python"`, `"javascript"`, `"json"`.
        let language: String?

        static let notCode = Verdict(isCode: false, language: nil)
    }

    /// Minimum length before the detector will even consider the input as
    /// code. Below this the cost of false positives is high.
    private static let minimumLength: Int = 20

    /// Score threshold at or above which a language claim is treated as
    /// strong enough to return `isCode: true`.
    private static let scoreThreshold: Int = 3

    /// Structural punctuation characters used for the first-pass filter.
    /// A source without at least one of these is almost certainly prose.
    private static let structuralCharacters: Set<Character> = [
        "{", "}", ";", ":", "=",
    ]

    // MARK: - Per-language keyword sets

    private static let swiftKeywords: Set<String> = [
        "func", "let", "var", "struct", "class", "guard", "enum", "protocol",
        "extension", "import", "if", "else", "for", "return",
    ]

    private static let pythonKeywords: Set<String> = [
        "def", "import", "from", "class", "return", "if", "elif", "else",
        "for", "while", "lambda", "yield",
    ]

    private static let javascriptKeywords: Set<String> = [
        "function", "const", "let", "var", "return", "if", "else", "for",
        "while", "=>", "async", "await",
    ]

    // MARK: - Public API

    /// Scores `source` across a handful of simple heuristics and returns
    /// the highest-scoring language when the score crosses the threshold.
    static func detect(_ source: String) -> Verdict {
        // Filter 1: too-short or punctuation-free sources are treated as prose.
        guard source.count >= minimumLength else { return .notCode }
        guard source.contains(where: structuralCharacters.contains) else {
            return .notCode
        }

        // Shebang takes precedence — if a line starts with `#!…env foo` we
        // trust it regardless of keyword/density scoring.
        if let shebangLanguage = shebangLanguage(in: source) {
            return Verdict(isCode: true, language: shebangLanguage)
        }

        // Tokenize once for keyword scoring.
        let tokens = source
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
        let tokenSet = Set(tokens)

        // Score each language.
        let swiftScore       = score(tokenSet: tokenSet, keywords: swiftKeywords)
        let pythonScore      = score(tokenSet: tokenSet, keywords: pythonKeywords)
        let javascriptScore  = score(tokenSet: tokenSet, keywords: javascriptKeywords)

        // Structural signals.
        let braceSemicolonScore = structuralScore(for: source)
        let jsonScore = jsonLikelihoodScore(for: source)

        // Aggregate per-language scores.
        let candidates: [(language: String, score: Int)] = [
            ("swift",      swiftScore      + braceSemicolonScore),
            ("python",     pythonScore     + (braceSemicolonScore / 2)),
            ("javascript", javascriptScore + braceSemicolonScore),
            ("json",       jsonScore),
        ]

        guard let best = candidates.max(by: { $0.score < $1.score }),
              best.score >= scoreThreshold else {
            return .notCode
        }

        return Verdict(isCode: true, language: best.language)
    }

    // MARK: - Scoring helpers

    /// Returns the number of distinct language keywords present in `tokenSet`.
    private static func score(tokenSet: Set<String>, keywords: Set<String>) -> Int {
        tokenSet.intersection(keywords).count
    }

    /// Contributes to generic brace-heavy languages (Swift, JavaScript, C, …).
    /// Counts `{`, `}` and `;` occurrences per 100 characters; returns a
    /// small bounded score.
    private static func structuralScore(for source: String) -> Int {
        let length = max(source.count, 1)
        let braces = source.reduce(0) { acc, ch in
            (ch == "{" || ch == "}") ? acc + 1 : acc
        }
        let semicolons = source.reduce(0) { $1 == ";" ? $0 + 1 : $0 }
        let density = Double(braces + semicolons) / Double(length) * 100.0

        switch density {
        case 0..<1: return 0
        case 1..<3: return 1
        case 3..<6: return 2
        default:    return 3
        }
    }

    /// Strong signal for JSON: trimmed content starts with `{` or `[` AND
    /// closing brace/bracket appears at or near the end.
    private static func jsonLikelihoodScore(for source: String) -> Int {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last else { return 0 }

        let startsBalanced = (first == "{" && last == "}") || (first == "[" && last == "]")
        guard startsBalanced else { return 0 }

        // Require at least one quoted key to avoid false-positive on any
        // text that happens to be brace-wrapped.
        let hasQuotedKey = trimmed.range(of: "\"[^\"]+\"\\s*:", options: .regularExpression) != nil
        return hasQuotedKey ? 4 : 2
    }

    // MARK: - Shebang

    /// Returns a language name when `source` begins with a recognised
    /// shebang line, otherwise `nil`.
    private static func shebangLanguage(in source: String) -> String? {
        guard let firstLine = source.split(whereSeparator: \.isNewline).first,
              firstLine.hasPrefix("#!") else {
            return nil
        }
        let line = firstLine.lowercased()
        if line.contains("swift") { return "swift" }
        if line.contains("python") { return "python" }
        if line.contains("node") { return "javascript" }
        if line.contains("bash") || line.contains("/sh") { return "bash" }
        return nil
    }
}
