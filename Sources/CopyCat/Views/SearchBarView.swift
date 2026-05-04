// SearchBarView.swift
// CopyCat
//
// Search bar with a text field, search icon, and match count indicator.
// Binds to HistoryStore.searchQuery to filter clipboard history.

import SwiftUI

/// A search bar view for filtering clipboard history items.
///
/// Displays a magnifying glass icon alongside a text field. When the search
/// query is non-empty, shows the count of matching items to the right.
struct SearchBarView: View {
    @Binding var searchQuery: String
    let matchCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search…", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Text("\(matchCount) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}
