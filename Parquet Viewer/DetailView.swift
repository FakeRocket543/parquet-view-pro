// Detail View
// Main content display area with data table and search
// SM-6: Data Display and Search Interface

import SwiftUI
import AppKit

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
            if dbManager.isLoading && !dbManager.hasLoadedFile {
                // Cold load only: nothing to keep on screen
                LoadingView(progress: dbManager.loadingProgress, message: dbManager.loadingMessage)
            } else if let csvIssue = dbManager.csvIssueResult, !dbManager.hasLoadedFile,
                      let fileURL = dbManager.currentFileURL ?? selectedFile {
                // First-load integrity issue: nothing behind it
                CSVIssueAlert(
                    checkResult: csvIssue,
                    fileURL: fileURL,
                    onDismiss: {
                        dbManager.csvIssueResult = nil
                    },
                    onAction: { action in
                        handleCSVRepairAction(action, fileURL: fileURL)
                    }
                )
            } else if !dbManager.hasLoadedFile {
                if let error = dbManager.errorMessage {
                    ErrorView(message: error, retry: retryAction)
                } else {
                    // Show welcome screen only when no file has been loaded
                    WelcomeView(onOpen: openFile)
                }
            } else {
                // Once a file is loaded the data area NEVER unmounts —
                // searches, pagination and jumps show an inline progress
                // strip so scroll position, selection and search focus
                // survive; the CSV alert layers on top as a sheet
                dataArea
                    .sheet(isPresented: csvIssueSheetBinding) {
                        if let csvIssue = dbManager.csvIssueResult,
                           let fileURL = dbManager.currentFileURL ?? selectedFile {
                            CSVIssueAlert(
                                checkResult: csvIssue,
                                fileURL: fileURL,
                                onDismiss: { dbManager.csvIssueResult = nil },
                                onAction: { action in
                                    handleCSVRepairAction(action, fileURL: fileURL)
                                }
                            )
                            .interactiveDismissDisabled(true)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var csvIssueSheetBinding: Binding<Bool> {
        Binding(
            get: { dbManager.csvIssueResult != nil && dbManager.hasLoadedFile },
            set: { if !$0 { dbManager.csvIssueResult = nil } }
        )
    }

    /// Search bar + table + overlays; survives reloads after first load
    @ViewBuilder
    private var dataArea: some View {
        VStack(spacing: 0) {
            if let error = dbManager.errorMessage, !dbManager.rows.isEmpty {
                // Error with data on screen → dismissible banner; the table
                // (search, sort, export) stays usable
                ErrorBanner(message: error, onDismiss: {
                    dbManager.errorMessage = nil
                }, onRetry: retryAction)
                Divider()
            }

            if dbManager.isLoading && !dbManager.rows.isEmpty {
                // Reload in flight with data visible → inline strip, table
                // stays mounted and interactive below
                HStack(spacing: 8) {
                    ProgressView(value: dbManager.loadingProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                    Text(dbManager.loadingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
            }

            tableContent
        }
    }

    private var retryAction: () -> Void {
        {
            // Prefer the file actually on screen (e.g. a repaired temp copy)
            // over selectedFile, which may be the original broken file
            if let file = dbManager.currentFileURL ?? selectedFile {
                // Retry must not re-apply the filter that may have caused
                // the failure — clear it, then reload the known-failed file
                dbManager.resetFilter()
                Task {
                    await dbManager.loadParquet(url: file, skipIntegrityCheck: true)
                }
            } else {
                openFile()
            }
        }
    }

    /// Search bar + data table / empty state (shared by the normal path and
    /// the error-banner path)
    @ViewBuilder
    private var tableContent: some View {
        VStack(spacing: 0) {
            // Search and Navigation bar
            SearchBarView(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                totalRowCount: dbManager.totalRowCount,
                currentStartRow: dbManager.currentStartRow,
                displayedRowCount: dbManager.displayedRowCount,
                onSearch: { searchText in
                    // Single funnel + dedupe: the clear button fires
                    // immediately and the debounced onChange repeats the
                    // same value — skip no-op reloads
                    let effective = searchText.isEmpty ? nil : searchText
                    guard effective != dbManager.activeFilterText else { return }
                    Task {
                        await dbManager.filterData(searchText: searchText)
                    }
                },
                onShowJumpDialog: {
                    showingJumpDialog = true
                }
            )

            Divider()

            // Data table, in-flight empty state, or empty search result
            if dbManager.rows.isEmpty {
                if dbManager.isLoading {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text("loading.generic".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = dbManager.errorMessage {
                    ErrorView(message: error, retry: retryAction)
                } else {
                    // Show "No results" message when search returns empty
                    EmptyResultsView(searchText: searchText) {
                        searchText = ""
                        Task {
                            await dbManager.filterData(searchText: "")
                        }
                    }
                }
            } else {
                // Data table - using ParquetTableView directly
                ParquetTableView(
                    columns: dbManager.columns,
                    rows: dbManager.rows,
                    startRow: dbManager.currentStartRow,
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

    /// Execute the repair action chosen in the CSV issue alert
    private func handleCSVRepairAction(_ action: CSVRepairAction, fileURL: URL) {
        switch action {
        case .ignoreAndLoad:
            Task {
                await dbManager.loadParquet(url: fileURL, skipIntegrityCheck: true)
            }
        case .skipLastRow:
            let upToRow = dbManager.csvIssueResult?.lastValidRowIndex ?? 0
            let manager = dbManager
            Task.detached(priority: .userInitiated) {
                // Whole-file read/parse/write must stay off the main actor —
                // this can be a multi-hundred-MB CSV
                if let truncated = CSVIntegrityChecker.createTruncatedContent(
                    from: fileURL, upToRow: upToRow
                ) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("skipped_\(UUID().uuidString)_\(fileURL.lastPathComponent)")
                    do {
                        try truncated.write(to: tempURL, atomically: true, encoding: .utf8)
                        // Manager owns temp cleanup alongside its transcodes
                        manager.registerTempFile(tempURL)
                        await manager.loadParquet(url: tempURL)
                        return
                    } catch {
                        await MainActor.run {
                            manager.errorMessage = "error.repair_write_failed".localizedWithFormat(error.localizedDescription)
                        }
                    }
                }
                // Fall back to tolerant loading if the repair write failed
                await manager.loadParquet(url: fileURL, skipIntegrityCheck: true)
            }
        case .openWithExternalTool:
            NSWorkspace.shared.open(fileURL)
        case .retryWithDifferentSettings:
            // Distinct from "ignore and load": re-run the integrity check
            // against the (presumably externally fixed) file instead of
            // skipping it
            dbManager.csvIssueResult = nil
            dbManager.integrityCheckSuppressed = false
            Task {
                await dbManager.loadParquet(url: fileURL)
            }
        }
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
                Text("loading.generic".localized)
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

            Text("error.title".localized)
                .font(.title)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .lineLimit(8)

            Button("button.retry".localized, action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Compact dismissible error banner shown above a still-usable table
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer()
            Button("button.retry".localized, action: onRetry)
                .buttonStyle(.borderless)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("alert.cancel".localized)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
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
                    Text("welcome.title".localized)
                        .font(.title)
                        .bold()

                    Text("welcome.subtitle".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        onOpen()
                    } label: {
                        Label("button.open_file".localized, systemImage: "folder")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("welcome.drag_drop".localized)
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
            Text("search.no_results".localized)
                .font(.title2)
                .bold()
            if !searchText.isEmpty {
                Text("search.no_match".localizedWithFormat(searchText))
                    .font(.body)
                    .foregroundColor(.secondary)
                Button {
                    onClearSearch()
                } label: {
                    Text("button.clear_search".localized)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("file.no_data".localized)
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
