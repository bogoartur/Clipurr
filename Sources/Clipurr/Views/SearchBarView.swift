// SearchBarView.swift
// Clipurr
//
// Search bar with a text field, search icon, and match count indicator.
// Binds to HistoryStore.searchQuery to filter clipboard history.

import SwiftUI

/// A search bar view for filtering clipboard history items.
///
/// Displays a magnifying glass icon alongside a text field inside a
/// Liquid Glass capsule, matching the look of Spotlight on macOS 26.
/// When the search query is non-empty, shows the count of matching items
/// and a clear button.
struct SearchBarView: View {
    @Binding var searchQuery: String
    let matchCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchQuery.isEmpty {
                Text("\(matchCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
