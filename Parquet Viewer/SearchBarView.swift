// Search Bar View
// Search interface with row navigation
// SM-5: Search and Navigation UI Component

import SwiftUI
import Combine

struct SearchBarView: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let totalRowCount: Int
    let currentStartRow: Int
    let displayedRowCount: Int
    let onSearch: (String) async -> Void
    let onShowJumpDialog: () -> Void

    // PERFORMANCE: Search debounce to prevent excessive queries
    @State private var searchCancellable: AnyCancellable?
    // Set while the clear button is resetting the field so the debounced
    // onChange path doesn't fire the same empty search a second time
    @State private var isClearingSearch = false

    var body: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFocused ? .blue : .secondary)
                TextField("search.placeholder".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        if isClearingSearch && newValue.isEmpty {
                            isClearingSearch = false
                            return  // the clear button already fired the search
                        }
                        // PERFORMANCE: Debounce search to prevent excessive queries
                        searchCancellable?.cancel()
                        searchCancellable = Just(newValue)
                            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
                            .sink { debouncedValue in
                                Task {
                                    await onSearch(debouncedValue)
                                }
                            }
                    }
                    .onSubmit {
                        // Immediate search on Enter key
                        searchCancellable?.cancel()
                        Task {
                            await onSearch(searchText)
                        }
                    }
                if !searchText.isEmpty {
                    Button {
                        isClearingSearch = true
                        searchText = ""
                        searchCancellable?.cancel()
                        Task {
                            await onSearch("")
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("button.clear_search".localized)
                }
            }
            .padding(8)
            .background(isSearchFocused ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSearchFocused ? Color.blue : Color.clear, lineWidth: 2)
            )
            .frame(maxWidth: .infinity)

            // Row info and jump button
            if totalRowCount > 1000 {
                Divider()
                    .frame(height: 20)

                Text("search.rows_range".localizedWithFormat(currentStartRow + 1, currentStartRow + displayedRowCount, totalRowCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize()

                Button {
                    onShowJumpDialog()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("tooltip.jump_to_row".localized)
                .accessibilityLabel("tooltip.jump_to_row".localized)
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @FocusState private var isSearchFocused: Bool

        var body: some View {
            SearchBarView(
                searchText: .constant(""),
                isSearchFocused: $isSearchFocused,
                totalRowCount: 50000,
                currentStartRow: 1000,
                displayedRowCount: 1000,
                onSearch: { _ in },
                onShowJumpDialog: { }
            )
        }
    }

    return PreviewWrapper()
}
