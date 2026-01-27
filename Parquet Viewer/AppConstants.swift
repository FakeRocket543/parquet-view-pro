// AppConstants.swift
// Application-wide constants and configurations
// Centralized constant management to avoid magic numbers

import Foundation
import AppKit

// MARK: - UI Constants

enum UIConstants {
    // Sidebar
    static let sidebarMinWidth: CGFloat = 220

    // Row Numbers
    static let rowNumberColumnWidth: CGFloat = 60

    // Table
    static let defaultTableFontSize: Double = 13.0
    static let minTableFontSize: Double = 9.0
    static let maxTableFontSize: Double = 20.0
    static let tableRowHeight: CGFloat = 28.0

    // Data Table Columns
    static let defaultColumnWidth: CGFloat = 150
    static let minColumnWidth: CGFloat = 50
    static let maxColumnWidth: CGFloat = 500

    // Settings Window
    static let settingsWindowWidth: CGFloat = 500
    static let settingsWindowHeight: CGFloat = 500
}

// MARK: - Data Constants

enum DataConstants {
    // Performance
    static let defaultMaxRows: Int = 1000
    static let minMaxRows: Int = 100
    static let maxMaxRows: Int = 10000
    static let maxRowsStep: Int = 100

    // Pagination
    static let paginationThreshold: Int = 10 // Load more when within 10 rows of bottom

    // Recent Files
    static let maxRecentFiles: Int = 10
}

// MARK: - File Type Helper

enum FileType: String, CaseIterable {
    case parquet = "parquet"
    case csv = "csv"

    var displayName: String {
        switch self {
        case .parquet: return "Parquet"
        case .csv: return "CSV"
        }
    }

    var fileExtension: String {
        return self.rawValue
    }

    var duckDBReadFunction: String {
        switch self {
        case .parquet: return "read_parquet"
        case .csv: return "read_csv"
        }
    }

    /// Get DuckDB read function with parameters for CSV
    func duckDBReadFunctionWithParams(path: String) -> String {
        switch self {
        case .parquet: return "read_parquet('\(path)')"
        case .csv: return "read_csv('\(path)', delim=',', header=true, autoDetect=true)"
        }
    }

    /// Detect file type from URL
    static func from(url: URL) -> FileType? {
        let ext = url.pathExtension.lowercased()
        return FileType(rawValue: ext)
    }

    /// Check if file type is supported
    static func isSupported(_ url: URL) -> Bool {
        return from(url: url) != nil
    }

    /// Get all supported file extensions
    static var supportedExtensions: [String] {
        return FileType.allCases.map { $0.fileExtension }
    }
}

// MARK: - Security Helper

enum SecurityHelper {
    /// Sanitize file path for SQL query
    /// Prevents SQL injection by properly escaping special characters
    static func sanitizePath(_ path: String) -> String? {
        // Validate path format
        guard !path.isEmpty else { return nil }

        // Prevent path traversal attacks
        guard !path.contains("..") else {
            return nil
        }

        // Escape special characters for SQL
        var sanitized = path

        // Escape single quotes (SQL)
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")

        // Escape backslashes (path separator on Windows, escape char in SQL)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")

        return sanitized
    }

    /// Validate file path and check if it's safe to access
    static func validateFilePath(_ url: URL) -> Result<Void, SecurityError> {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(path: url.path))
        }

        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .failure(.fileNotReadable(path: url.path))
        }

        // Check file type
        guard FileType.isSupported(url) else {
            return .failure(.unsupportedFileType(extension: url.pathExtension))
        }

        // Validate path doesn't contain dangerous patterns
        let path = url.path
        guard !path.contains("..") else {
            return .failure(.pathTraversal)
        }

        // Optionally: Restrict to certain directories (uncomment if needed)
        /*
        let allowedDirectories = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask),
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask),
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        ].flatMap { $0 }

        let isAllowed = allowedDirectories.contains { allowed in
            path.starts(with: allowed.path)
        }

        guard isAllowed else {
            return .failure(.accessDenied(path: path))
        }
        */

        return .success(())
    }
}

// MARK: - Security Error

enum SecurityError: LocalizedError {
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case unsupportedFileType(extension: String)
    case pathTraversal
    case accessDenied(path: String)
    case sqlInjectionAttempt

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileNotReadable(let path):
            return "Cannot read file: \(path)"
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)\nSupported types: \(FileType.supportedExtensions.joined(separator: ", "))"
        case .pathTraversal:
            return "Invalid file path: Path traversal detected"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .sqlInjectionAttempt:
            return "Security error: Invalid characters in query"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please check the file path and try again."
        case .fileNotReadable:
            return "Please check file permissions and try again."
        case .unsupportedFileType:
            return "Please select a Parquet or CSV file."
        case .pathTraversal:
            return "Please select a valid file path."
        case .accessDenied:
            return "Please select a file from your Documents or Downloads folder."
        case .sqlInjectionAttempt:
            return "Please contact support if you believe this is an error."
        }
    }
}
