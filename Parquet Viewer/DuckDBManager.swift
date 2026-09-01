// DuckDB Manager - FIXED FOR DuckDB-Swift 1.1.3 API
// Core database connection and Parquet file handling
// SM-3: Core DuckDB Manager Implementation

import Foundation
import DuckDB
import Combine

/// Manages DuckDB connection and Parquet file operations
class DuckDBManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var columns: [String] = []
    @Published var rows: [[String]] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalRowCount: Int = 0
    @Published var displayedRowCount: Int = 0
    @Published var fileInfo: FileInfo?
    @Published var currentStartRow: Int = 0
    @Published var hasLoadedFile: Bool = false  // NEW: Track if file is loaded
    @Published var loadingProgress: Double = 0.0  // Loading progress (0.0 to 1.0)
    @Published var loadingMessage: String = ""  // Loading status message
    @Published var columnStats: [String: ColumnStats] = [:]  // Column statistics
    @Published var sortColumn: String? = nil  // Current sort column
    @Published var sortAscending: Bool = true  // Sort direction
    @Published var isLoadingMore: Bool = false  // Loading more data
    @Published var csvIssueResult: CSVIntegrityCheckResult? = nil  // CSV integrity check result for UI handling
    /// One-shot instruction for the NEXT table render:
    /// nil = semantic reset (jump/filter/sort/file switch) — clear selection;
    /// n  = pure index shift (prepend +n, downward trim -overflow) — keep
    /// selection and anchor the scroll position.
    @Published var pendingRowShift: Int? = nil
    /// Bumped on every data publish — a reliable reload fingerprint (hashing
    /// rows can collide silently)
    @Published var dataVersion: UInt64 = 0
    
    // MARK: - Private Properties

    private var database: Database?
    private var connection: Connection?
    internal var currentFileURL: URL?  // Internal for CSV issue handling
    /// Active search filter (nil = unfiltered). Kept as state so that sort,
    /// jump and pagination all operate on the same filtered result set.
    var activeFilterText: String?
    var activeFilterColumn: String?
    /// Sticky per-file "ignore integrity issues" decision (set via the CSV
    /// issue alert or quick preview) so pagination doesn't re-prompt
    var integrityCheckSuppressed = false
    /// UTF-16 → UTF-8 transcode cache (source path → temp file), with the
    /// source size+mtime the twin was built from
    private var transcodedFiles: [String: URL] = [:]
    private var cachedStamp: [String: String] = [:]
    private var maxDisplayRows: Int

    /// Serializes access to the shared DuckDB Connection (it is not safe for
    /// concurrent use) and backs the operation-generation superseding below.
    private let dbLock = NSLock()
    /// Bumped by every public data operation; queries returning after a newer
    /// operation started discard their results instead of publishing stale
    /// state (e.g. an older debounced search finishing last).
    private var operationGeneration: UInt64 = 0
    /// True while a pagination page is loading (guarded by dbLock; NOT
    /// published — the published isLoadingMore is only a UI mirror)
    private var paginationInFlight = false

    // MARK: - Data Models

    struct FileInfo {
        let name: String
        let path: String
        let size: String
        let columnCount: Int
    }

    struct ColumnStats {
        let name: String
        let type: String
        let nullCount: Int
        let uniqueCount: Int
        let minValue: String?
        let maxValue: String?
        let avgValue: String?  // For numeric columns
    }

    // MARK: - Initialization

    init() {
        // Honor the user's Settings ▸ max rows preference if set
        let stored = UserDefaults.standard.integer(forKey: "maxRows")
        self.maxDisplayRows = stored > 0 ? stored : DataConstants.defaultMaxRows
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            // Use in-memory database for best performance
            database = try Database(store: .inMemory)
            connection = try database?.connect()
        } catch {
            errorMessage = "Failed to initialize DuckDB: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Public Methods
    
    /// Clear all data and return to empty state
    func clearData() {
        columns = []
        rows = []
        errorMessage = nil
        totalRowCount = 0
        displayedRowCount = 0
        fileInfo = nil
        currentStartRow = 0
        currentFileURL = nil
        hasLoadedFile = false  // Reset file loaded state
        loadingProgress = 0.0
        loadingMessage = ""
        columnStats = [:]
        // A superseded in-flight load hits its CancellationError arm and
        // assumes "a newer operation owns the loading state" — when the
        // superseder is clearData itself, nobody else will clear these
        isLoading = false
        isLoadingMore = false
        pendingRowShift = nil
        sortColumn = nil
        sortAscending = true
        activeFilterText = nil
        activeFilterColumn = nil
        csvIssueResult = nil
        isLoadingMore = false
        integrityCheckSuppressed = false
        removeTranscodedFiles()
        dbLock.lock()
        rowCountCache.removeAll()
        // Supersede any in-flight operation so it cannot repopulate the
        // cleared state after this point
        operationGeneration += 1
        dbLock.unlock()
    }

    deinit {
        // Temp transcodes must not outlive the manager (tab)
        for (_, temp) in transcodedFiles {
            try? FileManager.default.removeItem(at: temp)
        }
    }
    
    /// Load the page ABOVE the current window (upward pagination).
    /// Prepends rows and slides the window start back; the tail is trimmed
    /// by the same cap as downward pagination.
    func loadPreviousData() async {
        guard let fileURL = currentFileURL else { return }

        // Claim the in-flight flag in the SAME critical section that reads
        // the snapshot — momentum scrolling fires many triggers before a
        // MainActor hop could set a published flag
        dbLock.lock()
        if paginationInFlight || currentStartRow <= 0 {
            dbLock.unlock()
            return
        }
        paginationInFlight = true
        let pageStart = max(0, currentStartRow - maxDisplayRows)
        let limit = currentStartRow - pageStart
        dbLock.unlock()
        defer {
            dbLock.lock()
            paginationInFlight = false
            dbLock.unlock()
        }

        await MainActor.run { self.isLoadingMore = true }
        await loadParquet(url: fileURL, limit: limit, offset: pageStart, prependMode: true)
        await MainActor.run { self.isLoadingMore = false }
    }

    /// Load a Parquet file with optional row limit and offset
    func loadParquet(url: URL, limit: Int? = nil, offset: Int? = nil, skipIntegrityCheck: Bool = false, appendMode: Bool = false, prependMode: Bool = false) async {
        let generation = beginOperation()
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            if !appendMode && !prependMode {
                csvIssueResult = nil  // Reset previous issue
                // NOTE: previously-visible rows/columns are intentionally kept
                // until the new load succeeds, so a failed reload never wipes
                // the user's current view
            }
            loadingProgress = 0.0
            loadingMessage = appendMode ? "loading.appending".localized : "loading.message".localized
        }

        let rowLimit = limit ?? maxDisplayRows

        do {
            // SECURITY: Validate file path before processing
            switch SecurityHelper.validateFilePath(url) {
            case .success:
                break // Continue processing
            case .failure(let error):
                throw error
            }

            // Determine file type using centralized helper
            guard let fileType = FileType.from(url: url) else {
                throw SecurityError.unsupportedFileType(extension: url.pathExtension)
            }

            // A different file loaded into this manager must not inherit the
            // previous file's filter/sort/integrity decisions (pagination in
            // either direction keeps the same file)
            dbLock.lock()
            let isFileSwitch = !appendMode && !prependMode && url.path != currentFileURL?.path
            if isFileSwitch {
                activeFilterText = nil
                activeFilterColumn = nil
                integrityCheckSuppressed = false
            }
            let filterText = activeFilterText
            let filterColumn = activeFilterColumn
            dbLock.unlock()
            if isFileSwitch {
                // @Published sort state must be touched on the main actor
                await MainActor.run {
                    self.sortColumn = nil
                    self.sortAscending = true
                }
            }
            dbLock.lock()
            let sortColState = sortColumn
            let sortAscState = sortAscending
            dbLock.unlock()

            // DuckDB (1.1.3) garbles UTF-16 CSVs — transparently transcode to
            // a cached UTF-8 temp file and query that instead
            let queryURL = effectiveQueryURL(for: url, fileType: fileType)
            // SECURITY: Sanitize file path to prevent SQL injection (the
            // query path is the UTF-8 twin for UTF-16 sources)
            guard let path = SecurityHelper.sanitizePath(queryURL.path) else {
                throw SecurityError.sqlInjectionAttempt
            }

            // Remember the user's "ignore issues" decision for this file so
            // pagination (loadMoreData) doesn't re-run the check and throw
            // the alert back up mid-scroll
            if skipIntegrityCheck { integrityCheckSuppressed = true }

            // CSV integrity check (only for CSV/TSV files and when not explicitly skipped)
            if fileType.isCSVFamily && !skipIntegrityCheck && !integrityCheckSuppressed {
                let checkResult = CSVIntegrityChecker.check(
                    url: url,
                    delimiter: fileType == .tsv ? "\t" : ","
                )
                if !checkResult.isValid {
                    await MainActor.run {
                        self.csvIssueResult = checkResult
                        self.isLoading = false
                    }
                    return  // Stop loading and let UI handle the issue
                }
            }

            var countQuery: String
            var dataQuery: String
            let startOffset = offset ?? 0

            // Build FROM clause based on file type; `path` points at the
            // original file or its UTF-8 transcoded twin for UTF-16 CSVs
            let fromClause = fileType.fromClause(path: path)

            // Get column names first
            let schemaQuery = "SELECT * FROM \(fromClause) LIMIT 1"
            let schemaResult = try performQuery(schemaQuery)
            var columnNames: [String] = []
            for i in 0..<schemaResult.columnCount {
                columnNames.append(schemaResult.columnName(at: i))
            }
            try throwIfSuperseded(generation)

            // Active filter applies to count, data and pagination alike so
            // that sort / jump / load-more never mix unfiltered rows into a
            // filtered result set.
            let filterClause = Self.filterWhereClause(
                text: filterText, column: filterColumn, columns: columnNames
            )

            // Build queries using validated file type
            countQuery = "SELECT COUNT(*) as count FROM \(fromClause)\(filterClause.isEmpty ? "" : " \(filterClause)")"

            // Build data query with optional sorting.
            // Sort inside the subquery (native types), then CAST to VARCHAR
            // outside so every logical type renders correctly.
            let selectList = Self.varcharSelectList(columnNames)
            if let sortCol = sortColState, columnNames.contains(sortCol) {
                let sortDir = sortAscState ? "ASC" : "DESC"
                // Tiebreaker columns keep OFFSET pages deterministic when the
                // sort key has many equal values (DuckDB's sort is not
                // stable). Capped at 3 keys: measured cost is ~8-9x per extra
                // sort key on the embedded engine and deep OFFSET multiplies
                // it further.
                let tiebreakers = columnNames
                    .filter { $0 != sortCol }
                    .prefix(3)
                    .map { Self.quoteIdentifier($0) }
                    .joined(separator: ", ")
                dataQuery = """
                    SELECT \(selectList) FROM (
                        SELECT * FROM \(fromClause)\(filterClause.isEmpty ? "" : " \(filterClause)")
                        ORDER BY \(Self.quoteIdentifier(sortCol)) \(sortDir)\(tiebreakers.isEmpty ? "" : ", \(tiebreakers)")
                        LIMIT \(rowLimit) OFFSET \(startOffset)
                    )
                    """
            } else {
                dataQuery = """
                    SELECT \(selectList) FROM (
                        SELECT * FROM \(fromClause)\(filterClause.isEmpty ? "" : " \(filterClause)")
                        LIMIT \(rowLimit) OFFSET \(startOffset)
                    )
                    """
            }
            
            // Get total row count (cached per file+filter: every sort, jump
            // and load-more page used to re-run a full-file COUNT scan)
            await MainActor.run { self.loadingProgress = 0.1; self.loadingMessage = "loading.counting".localized }
            let countKey = path + "\u{0}" + filterClause
            let totalRows: Int
            if let cached = cachedCount(countKey) {
                totalRows = cached
            } else {
                let countResult = try performQuery(countQuery)
                try throwIfSuperseded(generation)
                // FIXED: Use DuckDB 1.1.3 API
                let countColumn = countResult.column(at: 0).cast(to: Int64.self)
                totalRows = Int(countColumn[0] ?? 0)
                storeCachedCount(countKey, count: totalRows)
            }

            await MainActor.run { self.loadingProgress = 0.3; self.loadingMessage = "loading.range".localizedWithFormat(startOffset, startOffset + rowLimit) }
            let dataResult = try performQuery(dataQuery)
            try throwIfSuperseded(generation)
            
            // Parse columns - FIXED: Use DuckDB 1.1.3 API
            var cols: [String] = []
            for i in 0..<dataResult.columnCount {
                cols.append(dataResult.columnName(at: i))
            }
            
            await MainActor.run { self.loadingProgress = 0.5; self.loadingMessage = "loading.parsing".localized }
            
            // Parse rows - FIXED: Use DuckDB 1.1.3 API
            var dataRows: [[String]] = []
            for rowIndex in 0..<dataResult.rowCount {
                var rowData: [String] = []
                for colIndex in 0..<dataResult.columnCount {
                    let column = dataResult.column(at: colIndex)
                    let stringValue = formatCellValue(column, at: Int(rowIndex))
                    rowData.append(stringValue)
                }
                dataRows.append(rowData)
                
                // Update progress every 100 rows
                if rowIndex % 100 == 0 {
                    let progress = 0.5 + (Double(rowIndex) / Double(dataResult.rowCount)) * 0.3
                    await MainActor.run { self.loadingProgress = progress }
                }
            }
            
            await MainActor.run { self.loadingProgress = 0.8; self.loadingMessage = "loading.finalizing".localized }
            
            // Skip statistics calculation during load - calculate on demand instead
            let stats: [String: ColumnStats] = [:]
            
            // Get file attributes
            let fileAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttrs[.size] as? UInt64 ?? 0
            let sizeString = formatFileSize(fileSize)
            
            let info = FileInfo(
                name: url.lastPathComponent,
                path: url.path,
                size: sizeString,
                columnCount: cols.count
            )
            
            // Copy to local variables to avoid capture warnings in Swift 6
            let finalCols = cols
            let finalRows = dataRows
            let finalRowCount = totalRows
            let finalDisplayCount = dataRows.count
            let finalInfo = info
            let finalStats = stats

            // A newer operation started while we were querying — drop these
            // results instead of publishing stale state over the new load
            try throwIfSuperseded(generation)

            await MainActor.run {
                // Re-check on the main actor: a generation bump between the
                // superseded-check above and this publish (clearData, a newer
                // op) must not resurrect stale state or double-append a page
                guard self.isCurrent(generation) else { return }

                self.dataVersion += 1
                self.pendingRowShift = nil  // default: semantic reset
                self.columns = finalCols
                // Publish the file as "current" only on success — after a
                // failed reload the still-visible rows must keep describing
                // the previous file (exports/jumps must not target file B
                // while the screen shows file A)
                self.currentFileURL = url
                if prependMode {
                    self.rows.insert(contentsOf: finalRows, at: 0)
                    self.currentStartRow = startOffset
                    if !finalRows.isEmpty { self.pendingRowShift = finalRows.count }
                    // Same window cap as downward pagination, trimming the tail
                    let windowCap = max(self.maxDisplayRows * 10, 10_000)
                    if self.rows.count > windowCap {
                        self.rows.removeLast(self.rows.count - windowCap)
                    }
                    self.displayedRowCount = self.rows.count
                } else if appendMode {
                    // COUNT(*) with ignore_errors can overcount (dropped
                    // rows still counted by the count fast-path) — converge
                    // to the observed end of data when a page comes back empty
                    if finalRows.isEmpty {
                        self.totalRowCount = min(self.totalRowCount, startOffset)
                        // the cached count is now known-wrong for this file
                        self.dbLock.lock()
                        self.rowCountCache.removeAll()
                        self.dbLock.unlock()
                    }
                    self.rows.append(contentsOf: finalRows)
                    // Sliding window: cap retained rows so scrolling through a
                    // multi-million-row file cannot accumulate unbounded
                    // memory; the gutter stays correct because
                    // currentStartRow advances with the window
                    let windowCap = max(self.maxDisplayRows * 10, 10_000)
                    if self.rows.count > windowCap {
                        let overflow = self.rows.count - windowCap
                        self.rows.removeFirst(overflow)
                        self.currentStartRow += overflow
                        self.pendingRowShift = -overflow
                    }
                    self.displayedRowCount = self.rows.count
                } else {
                    self.rows = finalRows
                    self.totalRowCount = finalRowCount
                    self.displayedRowCount = finalDisplayCount
                    self.fileInfo = finalInfo
                    self.columnStats = finalStats
                }
                self.currentStartRow = appendMode ? self.currentStartRow : startOffset
                self.hasLoadedFile = true
                self.loadingProgress = 1.0
                self.loadingMessage = "loading.complete".localized
                self.isLoading = false
            }

        } catch is CancellationError {
            // Superseded by a newer operation — it owns the loading state now
        } catch {
            await MainActor.run {
                // Truncate: DuckDB CSV errors can embed the entire offending
                // line (potentially megabytes) in one message
                var message = "Failed to load file: \(error.localizedDescription)"
                if message.count > 500 {
                    message = String(message.prefix(500)) + "…"
                }
                self.errorMessage = message
                self.isLoading = false
            }
        }
    }
    
    /// Export format
    enum ExportFormat {
        case csv
        case parquet
    }
    
    /// Export current data to CSV
    func exportToCSV(url: URL) async throws {
        try await exportData(to: url, format: .csv)
    }
    
    /// Export current data to Parquet
    func exportToParquet(url: URL) async throws {
        try await exportData(to: url, format: .parquet)
    }
    
    /// Export current data to specified format
    private func exportData(to url: URL, format: ExportFormat) async throws {
        guard let fileURL = currentFileURL else {
            throw NSError(domain: "Export", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No file loaded"])
        }

        // SECURITY: Sanitize paths to prevent SQL injection
        // (UTF-16 CSVs export from their transcoded twin).
        // Note: export re-reads the FULL source file — filter, sort and the
        // visible window do NOT apply.
        guard let fileType0 = FileType.from(url: fileURL) else {
            throw SecurityError.unsupportedFileType(extension: fileURL.pathExtension)
        }
        let sourceQueryURL = effectiveQueryURL(for: fileURL, fileType: fileType0)
        guard let sourcePath = SecurityHelper.sanitizePath(sourceQueryURL.path) else {
            throw SecurityError.sqlInjectionAttempt
        }
        guard let destPath = SecurityHelper.sanitizePath(url.path) else {
            throw SecurityError.sqlInjectionAttempt
        }

        // Refuse to export onto the source file (DuckDB would read and write
        // the same file, corrupting it). Resolve symlinks and compare
        // case-insensitively (APFS default) so /var vs /private/var or a
        // cased variant can't slip past.
        let sourceResolved = fileURL.resolvingSymlinksInPath().path.lowercased()
        let destResolved = url.resolvingSymlinksInPath().path.lowercased()
        guard sourceResolved != destResolved else {
            throw NSError(domain: "Export", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot export onto the file that is currently open"])
        }

        // Determine source file type using centralized helper
        guard let fileType = FileType.from(url: fileURL) else {
            throw SecurityError.unsupportedFileType(extension: fileURL.pathExtension)
        }

        // Build FROM clause based on file type
        let fromClause = fileType.fromClause(path: sourcePath)

        // Build read query using validated file type
        let readQuery = "SELECT * FROM \(fromClause)"
        
        // Build export query based on format
        let exportQuery: String
        switch format {
        case .csv:
            exportQuery = """
                COPY (\(readQuery))
                TO '\(destPath)' (HEADER, DELIMITER ',')
            """
        case .parquet:
            exportQuery = """
                COPY (\(readQuery))
                TO '\(destPath)' (FORMAT 'parquet')
            """
        }

        try performExecute(exportQuery)
    }
    
    /// Jump to specific row
    func jumpToRow(_ rowNumber: Int, rowsToLoad: Int? = nil) async {
        guard let fileURL = currentFileURL else { return }

        // Validate row number
        guard rowNumber > 0 && rowNumber <= totalRowCount else {
            await MainActor.run {
                self.errorMessage = "error.invalid_row".localizedWithFormat(totalRowCount)
            }
            return
        }

        // Convert to 0-based offset
        let offset = rowNumber - 1

        // Authoritative clamp: a jump never loads more than the global page
        // ceiling, regardless of what the caller passed
        let limit = min(rowsToLoad ?? maxDisplayRows, DataConstants.maxMaxRows)

        // Load data from specified row
        await loadParquet(url: fileURL, limit: limit, offset: offset)
    }

    /// Load more data (pagination)
    func loadMoreData() async {
        guard let fileURL = currentFileURL else { return }

        // Claim + snapshot in one critical section (see loadPreviousData)
        dbLock.lock()
        if paginationInFlight {
            dbLock.unlock()
            return
        }
        let startRow = currentStartRow
        let loaded = rows.count
        let total = totalRowCount
        guard startRow + loaded < total else {
            dbLock.unlock()
            return
        }
        paginationInFlight = true
        let newOffset = startRow + loaded
        dbLock.unlock()
        defer {
            dbLock.lock()
            paginationInFlight = false
            dbLock.unlock()
        }

        await MainActor.run {
            self.isLoadingMore = true
        }

        await loadParquet(url: fileURL, limit: maxDisplayRows, offset: newOffset, appendMode: true)

        await MainActor.run {
            self.isLoadingMore = false
        }
    }
    
    /// Check if there is more data to load.
    /// Compares the absolute end of the window (not just loaded count) so a
    /// jump to the final rows doesn't leave a permanently-true "load more"
    /// that fires empty queries on every scroll tick.
    var hasMoreData: Bool {
        currentStartRow + rows.count < totalRowCount
    }
    
    /// Sort data by column
    func sortByColumn(_ columnName: String, ascending: Bool = true) async {
        guard let fileURL = currentFileURL else { return }
        guard columns.contains(columnName) else { return }

        // @Published state must be written on the main actor (this method
        // runs on the cooperative pool); sorting also restarts the view at
        // the top — a sorted result set has no stable "current row"
        await MainActor.run {
            self.sortColumn = columnName
            self.sortAscending = ascending
        }

        // Reload data with sorting, from the top of the new order
        await loadParquet(url: fileURL, limit: maxDisplayRows, offset: 0)
    }

    /// Toggle sort direction for current column
    func toggleSort(for columnName: String) async {
        await MainActor.run {
            if self.sortColumn == columnName {
                self.sortAscending.toggle()
            } else {
                self.sortColumn = columnName
                self.sortAscending = true
            }
        }

        guard let fileURL = currentFileURL else { return }
        // Sorted results restart at the top of the new order
        await loadParquet(url: fileURL, limit: maxDisplayRows, offset: 0)
    }
    
    /// Calculate statistics on demand (called when user clicks Statistics button)
    func loadColumnStats() async {
        guard let fileURL = currentFileURL else { return }
        guard !columns.isEmpty else { return }

        // SECURITY: Sanitize path (queries use the UTF-8 twin when needed)
        guard let fileType = FileType.from(url: fileURL) else { return }
        let queryURL = effectiveQueryURL(for: fileURL, fileType: fileType)
        guard let path = SecurityHelper.sanitizePath(queryURL.path) else { return }

        let generation = beginOperation()
        await MainActor.run {
            self.isLoading = true
            self.loadingMessage = "loading.stats".localized
            self.loadingProgress = 0.0
        }

        do {
            let stats = try await calculateColumnStats(path: path, columns: columns, fileType: fileType, generation: generation)
            try throwIfSuperseded(generation)
            await MainActor.run {
                self.columnStats = stats
                self.isLoading = false
                self.loadingProgress = 1.0
            }
        } catch is CancellationError {
            // superseded — the newer operation owns the loading state
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to calculate statistics: \(error.localizedDescription)"
            }
        }
    }

    /// Calculate column statistics
    private func calculateColumnStats(path: String, columns: [String], fileType: FileType, generation: UInt64) async throws -> [String: ColumnStats] {
        guard connection != nil else { return [:] }

        // Build FROM clause based on file type
        let fromClause = fileType.fromClause(path: path)

        // Single-scan batched aggregates: five expressions per column in ONE
        // query (the previous per-column loop cost N+1 full-table scans —
        // minutes on a 1200-column file)
        do {
            var expressions: [String] = []
            expressions.reserveCapacity(columns.count * 5)
            for col in columns {
                let q = Self.quoteIdentifier(col)
                expressions.append("COUNT(*) - COUNT(\(q))")
                expressions.append("COUNT(DISTINCT \(q))")
                expressions.append("MIN(CAST(\(q) AS VARCHAR))")
                expressions.append("MAX(CAST(\(q) AS VARCHAR))")
                expressions.append("AVG(TRY_CAST(\(q) AS DOUBLE))")
            }
            let statsQuery = "SELECT \(expressions.joined(separator: ", ")) FROM \(fromClause)"

            let result = try performQuery(statsQuery)
            try throwIfSuperseded(generation)
            guard result.rowCount > 0 else { return [:] }

            await MainActor.run { self.loadingProgress = 0.9 }

            var stats: [String: ColumnStats] = [:]
            for (idx, col) in columns.enumerated() {
                // Result is a single row: pick the column by index, the row
                // is always 0
                let base = DBInt(idx * 5)
                let avg = result.column(at: base + 4).cast(to: Double.self)[0]
                stats[col] = ColumnStats(
                    name: col,
                    type: "Unknown", // Type detection would need more work
                    nullCount: Int(result.column(at: base).cast(to: Int64.self)[0] ?? 0),
                    uniqueCount: Int(result.column(at: base + 1).cast(to: Int64.self)[0] ?? 0),
                    minValue: result.column(at: base + 2).cast(to: String.self)[0],
                    maxValue: result.column(at: base + 3).cast(to: String.self)[0],
                    avgValue: avg.map { String(format: "%.4f", $0) }
                )
            }
            return stats
        } catch let cancelError as CancellationError {
            throw cancelError
        } catch {
            // One bad column breaks the whole batched query — fall back to
            // the per-column path that skips failing columns individually
            return try await perColumnStats(path: path, columns: columns, fromClause: fromClause, generation: generation)
        }
    }

    /// Fallback: per-column stats loop that silently skips failing columns
    private func perColumnStats(path: String, columns: [String], fromClause: String, generation: UInt64) async throws -> [String: ColumnStats] {
        var stats: [String: ColumnStats] = [:]
        let totalColumns = columns.count

        for (index, colName) in columns.enumerated() {
            let progress = Double(index) / Double(totalColumns)
            await MainActor.run { self.loadingProgress = progress }

            let statsQuery = """
                SELECT
                    COUNT(*) - COUNT(\(Self.quoteIdentifier(colName))) as null_count,
                    COUNT(DISTINCT \(Self.quoteIdentifier(colName))) as unique_count,
                    MIN(CAST(\(Self.quoteIdentifier(colName)) AS VARCHAR)) as min_val,
                    MAX(CAST(\(Self.quoteIdentifier(colName)) AS VARCHAR)) as max_val
                FROM \(fromClause)
                """

            do {
                let result = try performQuery(statsQuery)
                try throwIfSuperseded(generation)
                if result.rowCount > 0 {
                    var avgValue: String? = nil
                    let avgQuery = "SELECT AVG(TRY_CAST(\(Self.quoteIdentifier(colName)) AS DOUBLE)) as avg_val FROM \(fromClause)"
                    if let avgResult = try? performQuery(avgQuery),
                       let avg = avgResult.column(at: 0).cast(to: Double.self)[0] {
                        avgValue = String(format: "%.4f", avg)
                    }

                    stats[colName] = ColumnStats(
                        name: colName,
                        type: "Unknown",
                        nullCount: Int(result.column(at: 0).cast(to: Int64.self)[0] ?? 0),
                        uniqueCount: Int(result.column(at: 1).cast(to: Int64.self)[0] ?? 0),
                        minValue: result.column(at: 2).cast(to: String.self)[0],
                        maxValue: result.column(at: 3).cast(to: String.self)[0],
                        avgValue: avgValue
                    )
                }
            } catch let cancelError as CancellationError {
                throw cancelError
            } catch {
                // Silently skip columns that fail statistics calculation
                continue
            }
        }

        return stats
    }
    
    /// Clear the active filter WITHOUT reloading (used on error paths where
    /// a retry must not re-apply the filter that caused the failure)
    func resetFilter() {
        dbLock.lock()
        activeFilterText = nil
        activeFilterColumn = nil
        dbLock.unlock()
    }

    /// Search/filter data. Stores the filter as state and reloads through the
    /// unified load path, so sorting / jumping / pagination all stay within
    /// the filtered result set instead of mixing in unfiltered rows.
    func filterData(searchText: String, column: String? = nil) async {
        guard let fileURL = currentFileURL else { return }

        dbLock.lock()
        if searchText.isEmpty {
            activeFilterText = nil
            activeFilterColumn = nil
        } else {
            activeFilterText = searchText
            activeFilterColumn = column
        }
        dbLock.unlock()
        await loadParquet(url: fileURL)
    }

    // MARK: - Helper Methods

    // MARK: Connection serialization / operation superseding

    /// Claim the next operation generation. Results from operations holding
    /// an older generation are discarded.
    private func beginOperation() -> UInt64 {
        dbLock.lock()
        defer { dbLock.unlock() }
        operationGeneration += 1
        return operationGeneration
    }

    /// Throw CancellationError when a newer operation superseded `gen`.
    private func throwIfSuperseded(_ gen: UInt64) throws {
        if !isCurrent(gen) { throw CancellationError() }
    }

    // MARK: Row-count cache (guarded by dbLock)

    private var rowCountCache: [String: Int] = [:]

    private func cachedCount(_ key: String) -> Int? {
        dbLock.lock()
        defer { dbLock.unlock() }
        return rowCountCache[key]
    }

    private func storeCachedCount(_ key: String, count: Int) {
        dbLock.lock()
        defer { dbLock.unlock() }
        if rowCountCache.count > 64 { rowCountCache.removeAll() }
        rowCountCache[key] = count
    }

    /// True when `gen` is still the newest operation.
    private func isCurrent(_ gen: UInt64) -> Bool {
        dbLock.lock()
        defer { dbLock.unlock() }
        return gen == operationGeneration
    }

    /// Detect a UTF-16 BOM on CSV-family files.
    private func hasUTF16BOM(url: URL, fileType: FileType) -> Bool {
        guard fileType.isCSVFamily,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 2), head.count == 2 else { return false }
        return head == Data([0xFE, 0xFF]) || head == Data([0xFF, 0xFE])
    }

    /// UTF-16 CSV files: DuckDB (1.1.3) reads them as NUL-laden garbage.
    /// Transcode to UTF-8 once, cache per source path (validated against
    /// size+mtime so an edited source invalidates its twin), and query the
    /// twin. Cache access is serialized (this runs off the main actor).
    private func effectiveQueryURL(for url: URL, fileType: FileType) -> URL {
        guard hasUTF16BOM(url: url, fileType: fileType) else { return url }

        let stamp = fileStamp(url)
        dbLock.lock()
        if let cached = transcodedFiles[url.path], cachedStamp[url.path] == stamp {
            dbLock.unlock()
            return cached
        }
        dbLock.unlock()

        // Whole-file read: guard against pathological multi-GB UTF-16 CSVs
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64, size <= 512 * 1024 * 1024,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf16) else { return url }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pv_utf8_\(UUID().uuidString)_\(url.lastPathComponent)")
        do {
            try text.data(using: .utf8)?.write(to: temp)
            dbLock.lock()
            // Another operation may have won the race; drop our temp if so
            if let existing = transcodedFiles[url.path] {
                dbLock.unlock()
                try? FileManager.default.removeItem(at: temp)
                return existing
            }
            transcodedFiles[url.path] = temp
            cachedStamp[url.path] = stamp
            dbLock.unlock()
            return temp
        } catch {
            return url
        }
    }

    private func fileStamp(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? UInt64).map(String.init) ?? "?"
        let mtime = (attrs?[.modificationDate] as? Foundation.Date).map { String($0.timeIntervalSince1970) } ?? "?"
        return size + ":" + mtime
    }

    /// Register an owned-by-the-manager temp file (e.g. the "skip last row"
    /// repaired copy) so clearData/deinit removes it together with transcodes.
    func registerTempFile(_ url: URL) {
        dbLock.lock()
        defer { dbLock.unlock() }
        transcodedFiles[url.path] = url
    }

    private func removeTranscodedFiles() {
        dbLock.lock()
        let files = Array(transcodedFiles.values)
        transcodedFiles.removeAll()
        cachedStamp.removeAll()
        dbLock.unlock()
        for temp in files {
            try? FileManager.default.removeItem(at: temp)
        }
    }

    /// Run a query on the shared connection while holding the serialization
    /// lock, so overlapping UI actions can never use the Connection
    /// concurrently.
    private func performQuery(_ sql: String) throws -> ResultSet {
        guard let conn = connection else {
            throw NSError(domain: "DuckDB", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        dbLock.lock()
        defer { dbLock.unlock() }
        return try conn.query(sql)
    }

    private func performExecute(_ sql: String) throws {
        guard let conn = connection else {
            throw NSError(domain: "DuckDB", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        dbLock.lock()
        defer { dbLock.unlock() }
        try conn.execute(sql)
    }

    /// Build a WHERE clause for the active filter, or "" when unfiltered.
    /// The search text is escaped for a SQL literal and for LIKE wildcards;
    /// column names are escaped as quoted identifiers.
    static func filterWhereClause(text: String?, column: String?, columns: [String]) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        let likePattern = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "'", with: "''")

        let predicate = { (col: String) -> String in
            "CAST(\(quoteIdentifier(col)) AS VARCHAR) LIKE '%\(likePattern)%' ESCAPE '\\'"
        }

        if let col = column, columns.contains(col) {
            return "WHERE \(predicate(col))"
        }
        // Search across all columns. Chunked into parenthesized groups:
        // DuckDB's default max_expression_depth (1000) rejects one flat
        // left-deep OR chain on ~1200-column files
        guard !columns.isEmpty else { return "" }
        let predicates = columns.map(predicate)
        let chunks = stride(from: 0, to: predicates.count, by: 500).map {
            "(" + predicates[$0..<min($0 + 500, predicates.count)].joined(separator: " OR ") + ")"
        }
        return "WHERE \(chunks.joined(separator: " OR "))"
    }

    /// Escape a column name for safe use as a quoted SQL identifier.
    /// Column names come from untrusted file headers/schemas; doubling any
    /// embedded double quote prevents breaking out of the identifier.
    static func quoteIdentifier(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Build a SELECT list that renders every column as VARCHAR so that
    /// DECIMAL/TIMESTAMP/DATE/UUID/LIST/STRUCT/unsigned values display
    /// correctly instead of falling through to "NULL".
    private static func varcharSelectList(_ columnNames: [String]) -> String {
        columnNames
            .map { "CAST(\(quoteIdentifier($0)) AS VARCHAR) AS \(quoteIdentifier($0))" }
            .joined(separator: ", ")
    }

    // FIXED: formatCellValue for DuckDB 1.1.3 API
    // column is now Column<Void>, rowIndex is the row to access
    // Note: callers now CAST columns to VARCHAR in SQL, so the String path
    // below handles real values; the remaining casts are a safety net.
    private func formatCellValue(_ column: Column<Void>, at rowIndex: Int) -> String {
        // Convert Int to DBInt (UInt64)
        let dbIndex = DBInt(rowIndex)
        
        // Try different type casts in order of likelihood
        // Note: cast() always succeeds per DuckDB-Swift 1.1.3 API
        // If type doesn't match, column[index] returns nil
        
        // String
        let stringCol = column.cast(to: String.self)
        if let val = stringCol[dbIndex] {
            return val
        }
        
        // Int64 (most common integer type)
        let int64Col = column.cast(to: Int64.self)
        if let val = int64Col[dbIndex] {
            return String(val)
        }
        
        // Double
        let doubleCol = column.cast(to: Double.self)
        if let val = doubleCol[dbIndex] {
            // %g keeps significant digits without the historic trim bug that
            // turned 0.5 into "5" (unreachable since SQL-level VARCHAR cast,
            // kept as a correct safety net)
            return String(format: "%g", val)
        }
        
        // Boolean
        let boolCol = column.cast(to: Bool.self)
        if let val = boolCol[dbIndex] {
            return val ? "true" : "false"
        }
        
        // Int32
        let int32Col = column.cast(to: Int32.self)
        if let val = int32Col[dbIndex] {
            return String(val)
        }
        
        // If all else fails
        return "NULL"
    }
    
    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
