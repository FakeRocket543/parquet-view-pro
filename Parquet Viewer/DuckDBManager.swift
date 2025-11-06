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
    
    // MARK: - Private Properties
    
    private var database: Database?
    private var connection: Connection?
    private var currentFileURL: URL?
    private let maxDisplayRows = 1000
    
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
    
    // MARK: - Initialization
    
    init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            // Use in-memory database for best performance
            database = try Database(store: .inMemory)
            connection = try database?.connect()
            print("? DuckDB initialized successfully")
        } catch {
            errorMessage = "Failed to initialize DuckDB: \(error.localizedDescription)"
            print("? DuckDB initialization error: \(error)")
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
    }
    
    /// Load a Parquet file with optional row limit and offset
    func loadParquet(url: URL, limit: Int? = nil, offset: Int? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            columns = []
            rows = []
            totalRowCount = 0
            displayedRowCount = 0
        }
        
        currentFileURL = url
        let rowLimit = limit ?? maxDisplayRows
        
        do {
            guard let conn = connection else {
                throw NSError(domain: "DuckDB", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No database connection"])
            }
            
            // Escape single quotes in file path
            let path = url.path.replacingOccurrences(of: "'", with: "''")
            
            // Determine file type and use appropriate DuckDB function
            let fileExtension = url.pathExtension.lowercased()
            let countQuery: String
            let dataQuery: String
            let startOffset = offset ?? 0
            
            switch fileExtension {
            case "csv":
                // CSV: Use read_csv_auto with proper syntax
                countQuery = "SELECT COUNT(*) as count FROM read_csv_auto('\(path)')"
                dataQuery = """
                    SELECT * FROM read_csv_auto('\(path)')
                    LIMIT \(rowLimit) OFFSET \(startOffset)
                """
            case "parquet":
                // Parquet: Use read_parquet
                countQuery = "SELECT COUNT(*) as count FROM read_parquet('\(path)')"
                dataQuery = """
                    SELECT * FROM read_parquet('\(path)')
                    LIMIT \(rowLimit) OFFSET \(startOffset)
                """
            default:
                // Default to parquet
                countQuery = "SELECT COUNT(*) as count FROM read_parquet('\(path)')"
                dataQuery = """
                    SELECT * FROM read_parquet('\(path)')
                    LIMIT \(rowLimit) OFFSET \(startOffset)
                """
            }
            
            // Get total row count
            print("?? Executing count query...")
            let countResult = try conn.query(countQuery)
            
            // FIXED: Use DuckDB 1.1.3 API
            let countColumn = countResult.column(at: 0).cast(to: Int64.self)
            let totalRows = Int(countColumn[0] ?? 0)
            print("?? Loading data (offset: \(startOffset), limit: \(rowLimit))...")
            let dataResult = try conn.query(dataQuery)
            
            // Parse columns - FIXED: Use DuckDB 1.1.3 API
            var cols: [String] = []
            for i in 0..<dataResult.columnCount {
                cols.append(dataResult.columnName(at: i))
            }
            
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
            }
            
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
            
            await MainActor.run {
                self.columns = finalCols
                self.rows = finalRows
                self.totalRowCount = finalRowCount
                self.displayedRowCount = finalDisplayCount
                self.fileInfo = finalInfo
                self.currentStartRow = startOffset
                self.hasLoadedFile = true  // Mark that a file has been loaded
                self.isLoading = false
            }
            
            print("? Loaded \(dataRows.count) rows from \(url.lastPathComponent)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("? Error loading file: \(error)")
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
        
        // Use DuckDB to export directly
        let sourcePath = fileURL.path.replacingOccurrences(of: "'", with: "''")
        let destPath = url.path.replacingOccurrences(of: "'", with: "''")
        
        // Determine source file type and build read query
        let fileExtension = fileURL.pathExtension.lowercased()
        let readQuery: String
        switch fileExtension {
        case "csv":
            readQuery = "SELECT * FROM read_csv_auto('\(sourcePath)')"
        case "parquet":
            readQuery = "SELECT * FROM read_parquet('\(sourcePath)')"
        default:
            readQuery = "SELECT * FROM read_parquet('\(sourcePath)')"
        }
        
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
        print("? Exported to \(format.displayName): \(url.lastPathComponent)")
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
            
            let path = fileURL.path.replacingOccurrences(of: "'", with: "''")
            let searchPattern = searchText.replacingOccurrences(of: "'", with: "''")
            
            // Determine file type
            let fileExtension = fileURL.pathExtension.lowercased()
            let readFunction = (fileExtension == "csv") ? "read_csv" : "read_parquet"
            
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
                SELECT * FROM \(readFunction)('\(path)')
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
