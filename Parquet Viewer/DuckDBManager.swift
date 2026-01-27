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

    // CSV integrity check result (stored as optional for UI handling)
    var csvIssueResult: CSVIntegrityCheckResult? = nil
    
    // MARK: - Private Properties
    
    private var database: Database?
    private var connection: Connection?
    internal var currentFileURL: URL?  // Internal for CSV issue handling
    private let maxDisplayRows = DataConstants.defaultMaxRows
    
    // MARK: - Data Models
    
    struct FileInfo {
        let name: String
        let path: String
        let size: String
        let columnCount: Int
    }
    
    struct ColumnInfo {
        let name: String
        let type: String
        let nullCount: Int
        let uniqueCount: Int
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
        sortColumn = nil
        sortAscending = true
    }
    
    /// Load a Parquet file with optional row limit and offset
    func loadParquet(url: URL, limit: Int? = nil, offset: Int? = nil, quickPreview: Bool = false, skipIntegrityCheck: Bool = false) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            csvIssueResult = nil  // Reset previous issue
            columns = []
            rows = []
            totalRowCount = 0
            displayedRowCount = 0
            loadingProgress = 0.0
            loadingMessage = quickPreview ? "Quick preview loading..." : "Loading file..."
        }

        currentFileURL = url
        let rowLimit = quickPreview ? 100 : (limit ?? maxDisplayRows)

        do {
            guard let conn = connection else {
                throw NSError(domain: "DuckDB", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No database connection"])
            }

            // SECURITY: Validate file path before processing
            switch SecurityHelper.validateFilePath(url) {
            case .success:
                break // Continue processing
            case .failure(let error):
                throw error
            }

            // SECURITY: Sanitize file path to prevent SQL injection
            guard let path = SecurityHelper.sanitizePath(url.path) else {
                throw SecurityError.sqlInjectionAttempt
            }

            // Determine file type using centralized helper
            guard let fileType = FileType.from(url: url) else {
                throw SecurityError.unsupportedFileType(extension: url.pathExtension)
            }

            // CSV integrity check (only for CSV files and when not explicitly skipped)
            if fileType == .csv && !skipIntegrityCheck && !quickPreview {
                let checkResult = CSVIntegrityChecker.check(url: url)
                if !checkResult.isValid {
                    await MainActor.run {
                        self.csvIssueResult = checkResult
                        self.isLoading = false
                    }
                    return  // Stop loading and let UI handle the issue
                }
            }

            let countQuery: String
            var dataQuery: String
            let startOffset = offset ?? 0

            // Build FROM clause based on file type with explicit parameters for CSV
            let fromClause: String
            if fileType == .csv {
                // Use read_csv with explicit parameters for better parsing
                fromClause = "read_csv('\(path)', delim=',', quote='\"', escape='\"', header=true, ignore_errors=true, auto_detect=false)"
            } else {
                fromClause = "\(fileType.duckDBReadFunction)('\(path)')"
            }

            // Build queries using validated file type
            countQuery = "SELECT COUNT(*) as count FROM \(fromClause)"

            // Get column names first
            let schemaQuery = "SELECT * FROM \(fromClause) LIMIT 1"
            let schemaResult = try conn.query(schemaQuery)
            var columnNames: [String] = []
            for i in 0..<schemaResult.columnCount {
                columnNames.append(schemaResult.columnName(at: i))
            }

            // Build data query with optional sorting
            if let sortCol = sortColumn, columnNames.contains(sortCol) {
                let sortDir = sortAscending ? "ASC" : "DESC"
                dataQuery = """
                    SELECT * FROM \(fromClause)
                    ORDER BY "\(sortCol)" \(sortDir)
                    LIMIT \(rowLimit) OFFSET \(startOffset)
                    """
            } else {
                dataQuery = """
                    SELECT * FROM \(fromClause)
                    LIMIT \(rowLimit) OFFSET \(startOffset)
                    """
            }
            
            // Get total row count
            await MainActor.run { self.loadingProgress = 0.1; self.loadingMessage = "Counting rows..." }
            let countResult = try conn.query(countQuery)
            
            // FIXED: Use DuckDB 1.1.3 API
            let countColumn = countResult.column(at: 0).cast(to: Int64.self)
            let totalRows = Int(countColumn[0] ?? 0)
            
            await MainActor.run { self.loadingProgress = 0.3; self.loadingMessage = "Loading data (\(startOffset) to \(startOffset + rowLimit))..." }
            let dataResult = try conn.query(dataQuery)
            
            // Parse columns - FIXED: Use DuckDB 1.1.3 API
            var cols: [String] = []
            for i in 0..<dataResult.columnCount {
                cols.append(dataResult.columnName(at: i))
            }
            
            await MainActor.run { self.loadingProgress = 0.5; self.loadingMessage = "Parsing data..." }
            
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
            
            await MainActor.run { self.loadingProgress = 0.8; self.loadingMessage = "Finalizing..." }
            
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

            await MainActor.run {
                self.columns = finalCols
                self.rows = finalRows
                self.totalRowCount = finalRowCount
                self.displayedRowCount = finalDisplayCount
                self.fileInfo = finalInfo
                self.currentStartRow = startOffset
                self.hasLoadedFile = true  // Mark that a file has been loaded
                self.columnStats = finalStats
                self.loadingProgress = 1.0
                self.loadingMessage = "Complete!"
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Export format
    enum ExportFormat {
        case csv
        case parquet
        
        var displayName: String {
            switch self {
            case .csv: return "CSV"
            case .parquet: return "Parquet"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .parquet: return "parquet"
            }
        }
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
        
        guard let conn = connection else {
            throw NSError(domain: "Export", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }

        // SECURITY: Sanitize paths to prevent SQL injection
        guard let sourcePath = SecurityHelper.sanitizePath(fileURL.path) else {
            throw SecurityError.sqlInjectionAttempt
        }
        guard let destPath = SecurityHelper.sanitizePath(url.path) else {
            throw SecurityError.sqlInjectionAttempt
        }

        // Determine source file type using centralized helper
        guard let fileType = FileType.from(url: fileURL) else {
            throw SecurityError.unsupportedFileType(extension: fileURL.pathExtension)
        }

        // Build FROM clause based on file type with explicit parameters for CSV
        let fromClause: String
        if fileType == .csv {
            // Use read_csv with explicit parameters for export compatibility
            fromClause = "read_csv('\(sourcePath)', delim=',', quote='\"', escape='\"', header=true, auto_detect=false)"
        } else {
            fromClause = "\(fileType.duckDBReadFunction)('\(sourcePath)')"
        }

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

        try conn.execute(exportQuery)
    }
    
    /// Jump to specific row
    func jumpToRow(_ rowNumber: Int, rowsToLoad: Int = 1000) async {
        guard let fileURL = currentFileURL else { return }
        
        // Validate row number
        guard rowNumber > 0 && rowNumber <= totalRowCount else {
            await MainActor.run {
                self.errorMessage = "Invalid row number. Must be between 1 and \(totalRowCount)"
            }
            return
        }
        
        // Convert to 0-based offset
        let offset = rowNumber - 1
        
        // Load data from specified row
        await loadParquet(url: fileURL, limit: rowsToLoad, offset: offset)
    }
    
    /// Sort data by column
    func sortByColumn(_ columnName: String, ascending: Bool = true) async {
        guard let fileURL = currentFileURL else { return }
        guard columns.contains(columnName) else { return }
        
        sortColumn = columnName
        sortAscending = ascending
        
        // Reload data with sorting
        await loadParquet(url: fileURL, limit: maxDisplayRows, offset: currentStartRow)
    }
    
    /// Toggle sort direction for current column
    func toggleSort(for columnName: String) async {
        if sortColumn == columnName {
            sortAscending.toggle()
        } else {
            sortColumn = columnName
            sortAscending = true
        }
        
        guard let fileURL = currentFileURL else { return }
        await loadParquet(url: fileURL, limit: maxDisplayRows, offset: currentStartRow)
    }
    
    /// Calculate statistics on demand (called when user clicks Statistics button)
    func loadColumnStats() async {
        guard let fileURL = currentFileURL else { return }
        guard !columns.isEmpty else { return }

        // SECURITY: Sanitize path
        guard let path = SecurityHelper.sanitizePath(fileURL.path) else { return }
        guard let fileType = FileType.from(url: fileURL) else { return }

        await MainActor.run {
            self.isLoading = true
            self.loadingMessage = "Calculating statistics..."
            self.loadingProgress = 0.0
        }

        do {
            let stats = try await calculateColumnStats(path: path, columns: columns, fileType: fileType)
            await MainActor.run {
                self.columnStats = stats
                self.isLoading = false
                self.loadingProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to calculate statistics: \(error.localizedDescription)"
            }
        }
    }

    /// Calculate column statistics
    private func calculateColumnStats(path: String, columns: [String], fileType: FileType) async throws -> [String: ColumnStats] {
        guard let conn = connection else { return [:] }

        // Build FROM clause based on file type with explicit parameters for CSV
        let fromClause: String
        if fileType == .csv {
            fromClause = "read_csv('\(path)', delim=',', quote='\"', escape='\"', header=true, ignore_errors=true, auto_detect=false)"
        } else {
            fromClause = "\(fileType.duckDBReadFunction)('\(path)')"
        }

        var stats: [String: ColumnStats] = [:]
        let totalColumns = columns.count

        for (index, colName) in columns.enumerated() {
            // Update progress
            let progress = Double(index) / Double(totalColumns)
            await MainActor.run { self.loadingProgress = progress }

            // Get NULL count and unique count
            let statsQuery = """
                SELECT
                    COUNT(*) - COUNT("\(colName)") as null_count,
                    COUNT(DISTINCT "\(colName)") as unique_count,
                    MIN(CAST("\(colName)" AS VARCHAR)) as min_val,
                    MAX(CAST("\(colName)" AS VARCHAR)) as max_val
                FROM \(fromClause)
                """
            
            do {
                let result = try conn.query(statsQuery)
                if result.rowCount > 0 {
                    let nullCount = Int(result.column(at: 0).cast(to: Int64.self)[0] ?? 0)
                    let uniqueCount = Int(result.column(at: 1).cast(to: Int64.self)[0] ?? 0)
                    let minVal = result.column(at: 2).cast(to: String.self)[0]
                    let maxVal = result.column(at: 3).cast(to: String.self)[0]
                    
                    // Try to calculate average for numeric columns
                    var avgValue: String? = nil
                    let avgQuery = "SELECT AVG(TRY_CAST(\"\(colName)\" AS DOUBLE)) as avg_val FROM \(fromClause)"
                    if let avgResult = try? conn.query(avgQuery),
                       let avg = avgResult.column(at: 0).cast(to: Double.self)[0] {
                        avgValue = String(format: "%.4f", avg)
                    }
                    
                    stats[colName] = ColumnStats(
                        name: colName,
                        type: "Unknown", // Type detection would need more work
                        nullCount: nullCount,
                        uniqueCount: uniqueCount,
                        minValue: minVal,
                        maxValue: maxVal,
                        avgValue: avgValue
                    )
                }
            } catch {
                // Silently skip columns that fail statistics calculation
                continue
            }
        }
        
        return stats
    }
    
    /// Search/filter data
    func filterData(searchText: String, column: String? = nil) async {
        guard let fileURL = currentFileURL else { return }
        guard !searchText.isEmpty else {
            // Reload original data
            await loadParquet(url: fileURL)
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let conn = connection else {
                throw NSError(domain: "DuckDB", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No database connection"])
            }

            // SECURITY: Sanitize path and search pattern
            guard let path = SecurityHelper.sanitizePath(fileURL.path) else {
                throw SecurityError.sqlInjectionAttempt
            }
            guard let searchPattern = SecurityHelper.sanitizePath(searchText) else {
                throw SecurityError.sqlInjectionAttempt
            }

            // Determine file type using centralized helper
            guard let fileType = FileType.from(url: fileURL) else {
                throw SecurityError.unsupportedFileType(extension: fileURL.pathExtension)
            }

            // Build FROM clause based on file type with explicit parameters for CSV
            let fromClause: String
            if fileType == .csv {
                // Use read_csv with explicit parameters for better parsing
                fromClause = "read_csv('\(path)', delim=',', quote='\"', escape='\"', header=true, ignore_errors=true, auto_detect=false)"
            } else {
                fromClause = "\(fileType.duckDBReadFunction)('\(path)')"
            }

            var whereClause = ""
            if let col = column {
                whereClause = "WHERE CAST(\"\(col)\" AS VARCHAR) LIKE '%\(searchPattern)%'"
            } else {
                // Search across all columns
                let conditions = columns.map { col in
                    "CAST(\"\(col)\" AS VARCHAR) LIKE '%\(searchPattern)%'"
                }.joined(separator: " OR ")
                whereClause = "WHERE \(conditions)"
            }

            let query = """
                SELECT * FROM \(fromClause)
                \(whereClause)
                LIMIT \(maxDisplayRows)
            """
            
            let result = try conn.query(query)
            
            // FIXED: Use DuckDB 1.1.3 API
            var dataRows: [[String]] = []
            for rowIndex in 0..<result.rowCount {
                var rowData: [String] = []
                for colIndex in 0..<result.columnCount {
                    let column = result.column(at: colIndex)
                    let stringValue = formatCellValue(column, at: Int(rowIndex))
                    rowData.append(stringValue)
                }
                dataRows.append(rowData)
            }

            // Copy to local variables to avoid capture warnings in Swift 6
            let finalRows = dataRows
            let finalCount = dataRows.count

            await MainActor.run {
                self.rows = finalRows
                self.displayedRowCount = finalCount
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Filter failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // FIXED: formatCellValue for DuckDB 1.1.3 API
    // column is now Column<Void>, rowIndex is the row to access
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
            // Format double nicely
            return String(format: "%.6f", val)
                .trimmingCharacters(in: CharacterSet(charactersIn: "0"))
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
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
