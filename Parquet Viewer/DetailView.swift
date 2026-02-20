// Detail View
// Main content display area with data table and search
// SM-6: Data Display and Search Interface

import SwiftUI

struct DetailView: View {
    @ObservedObject var dbManager: DuckDBManager
    @Binding var selectedFile: URL?
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @Binding var showingJumpDialog: Bool
    @Binding var jumpToRowNumber: String
    @Binding var jumpRowCount: String
    let openFile: () -> Void

    var body: some View {
        Group {
            if dbManager.isLoading {
                LoadingView(progress: dbManager.loadingProgress, message: dbManager.loadingMessage)
            } else if let error = dbManager.errorMessage {
                ErrorView(message: error, retry: {
                    if selectedFile != nil {
                        openFile()
                    }
                })
            } else if !dbManager.hasLoadedFile {
                // Show welcome screen only when no file has been loaded
                WelcomeView(onOpen: openFile)
            } else {
                // Show table view even if rows are empty (search result might be empty)
                VStack(spacing: 0) {
                    // Search and Navigation bar
                    SearchBarView(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        totalRowCount: dbManager.totalRowCount,
                        currentStartRow: dbManager.currentStartRow,
                        displayedRowCount: dbManager.displayedRowCount,
                        onSearch: { searchText in
                            Task {
                                await dbManager.filterData(searchText: searchText)
                            }
                        },
                        onShowJumpDialog: {
                            showingJumpDialog = true
                        }
                    )

                    Divider()

                    // Data table or empty search result message
                    if dbManager.rows.isEmpty {
                        // Show "No results" message when search returns empty
                        EmptyResultsView(searchText: searchText) {
                            searchText = ""
                            Task {
                                await dbManager.filterData(searchText: "")
                            }
                        }
                    } else {
                        // Data table - using ParquetTableView directly
                        ParquetTableView(
                            columns: dbManager.columns,
                            rows: dbManager.rows,
                            onLoadMore: {
                                Task {
                                    await dbManager.loadMoreData()
                                }
                            },
                            hasMoreData: dbManager.hasMoreData,
                            isLoadingMore: dbManager.isLoadingMore,
                            sortColumn: dbManager.sortColumn,
                            sortAscending: dbManager.sortAscending,
                            onSort: { columnName in
                                Task {
                                    await dbManager.toggleSort(for: columnName)
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    let progress: Double
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 300)

            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.title)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct WelcomeView: View {
    let onOpen: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("Welcome to Parquet View")
                        .font(.title)
                        .bold()

                    Text("Open a Parquet or CSV file to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        onOpen()
                    } label: {
                        Label("Open File", systemImage: "folder")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("or drag and drop a file here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyResultsView: View {
    let searchText: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Results Found")
                .font(.title2)
                .bold()
            if !searchText.isEmpty {
                Text("No data matches '\(searchText)'")
                    .font(.body)
                    .foregroundColor(.secondary)
                Button {
                    onClearSearch()
                } label: {
                    Text("Clear Search")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("This file contains no data")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    DetailView(
        dbManager: DuckDBManager(),
        selectedFile: .constant(nil),
        searchText: .constant(""),
        isSearchFocused: FocusState<Bool>().projectedValue,
        showingJumpDialog: .constant(false),
        jumpToRowNumber: .constant(""),
        jumpRowCount: .constant("1000"),
        openFile: {}
    )
}
