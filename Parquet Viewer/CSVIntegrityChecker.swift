// CSV Integrity Checker
// Validates CSV file integrity and provides repair suggestions

import Foundation

/// Result of CSV integrity check
struct CSVIntegrityCheckResult: Equatable {
    let isValid: Bool
    let issueType: IssueType?
    let issueDescription: String?
    let suggestedActions: [CSVRepairAction]
    let lastValidRowIndex: Int  // 0-based index of last valid row

    enum IssueType: Equatable {
        case truncatedLastRow      // Last row has incomplete fields
        case mismatchedColumns     // Row has different number of columns than header
        case unmatchedQuotes       // Odd number of quotes in a row
        case encodingError         // File encoding issues
        case emptyFile             // File is empty
    }

    static func == (lhs: CSVIntegrityCheckResult, rhs: CSVIntegrityCheckResult) -> Bool {
        return lhs.isValid == rhs.isValid &&
               lhs.issueType == rhs.issueType &&
               lhs.issueDescription == rhs.issueDescription &&
               lhs.lastValidRowIndex == rhs.lastValidRowIndex
    }
}

/// Actions user can take to repair CSV issues
enum CSVRepairAction: Identifiable {
    case ignoreAndLoad           // Load as-is with DuckDB error tolerance
    case skipLastRow             // Skip the last incomplete row
    case openWithExternalTool    // Suggest opening with text editor
    case retryWithDifferentSettings // Try different CSV parsing options

    var id: String { description }

    var description: String {
        switch self {
        case .ignoreAndLoad:
            return "csv.action.ignore_and_load".localized
        case .skipLastRow:
            return "csv.action.skip_last_row".localized
        case .openWithExternalTool:
            return "csv.action.open_external".localized
        case .retryWithDifferentSettings:
            return "csv.action.retry_settings".localized
        }
    }

    var icon: String {
        switch self {
        case .ignoreAndLoad: return "arrow.down.doc"
        case .skipLastRow: return "trash"
        case .openWithExternalTool: return "externaltool"
        case .retryWithDifferentSettings: return "gear"
        }
    }
}

/// Checks CSV file integrity before loading
class CSVIntegrityChecker {

    /// Integrity checks stream at most this many bytes from the head of the
    /// file so a multi-GB CSV cannot exhaust memory.
    static let maxCheckBytes = 2 * 1024 * 1024
    private static var maxCheckBytesUInt: UInt64 { UInt64(maxCheckBytes) }

    /// Check CSV file integrity
    /// - Parameter delimiter: field delimiter ("," for CSV, "\t" for TSV)
    static func check(url: URL, delimiter: Character = ",") -> CSVIntegrityCheckResult {
        // First check if file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "csv.issue.not_found".localized,
                suggestedActions: [],
                lastValidRowIndex: 0
            )
        }

        // Check file size
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64,
              fileSize > 0 else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "csv.issue.empty".localized,
                suggestedActions: [],
                lastValidRowIndex: 0
            )
        }

        // Read at most maxCheckBytes from the head of the file.
        // hitCap must compare against the REAL file size: a file that is an
        // exact multiple of the cap would otherwise have its perfectly valid
        // final record dropped as "possibly truncated".
        let data: Data
        let hitCap: Bool
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            data = handle.readData(ofLength: maxCheckBytes)
            hitCap = UInt64(data.count) >= maxCheckBytesUInt && fileSize > UInt64(data.count)
        } catch {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .encodingError,
                issueDescription: "csv.issue.encoding".localized,
                suggestedActions: [.openWithExternalTool],
                lastValidRowIndex: 0
            )
        }

        // Decode: UTF-8 first; UTF-16 only when a BOM says so (almost any
        // byte sequence would otherwise "decode" as UTF-16 garbage). When the
        // 2 MB cap lands mid-character, trim 1–3 trailing bytes until the
        // decode succeeds (a fixed 3-byte trim can still land inside the
        // preceding multi-byte character and falsely reject valid CJK files).
        let content: String?
        if let s = String(data: data, encoding: .utf8) {
            content = s
        } else if hitCap {
            var trimmed: String? = nil
            var cut = 1
            while cut <= 3 && data.count > cut {
                if let s = String(data: data.prefix(data.count - cut), encoding: .utf8) {
                    trimmed = s
                    break
                }
                cut += 1
            }
            content = trimmed
        } else if data.starts(with: [0xFE, 0xFF]) || data.starts(with: [0xFF, 0xFE]) {
            var utf16Data = data
            if hitCap && utf16Data.count % 2 == 1 {
                utf16Data = utf16Data.prefix(utf16Data.count - 1)
            }
            content = String(data: utf16Data, encoding: .utf16)
        } else {
            content = nil
        }

        guard let decodedContent = content else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .encodingError,
                issueDescription: "csv.issue.encoding".localized,
                suggestedActions: [.openWithExternalTool],
                lastValidRowIndex: 0
            )
        }

        // Split into records with a quote-aware state machine so quoted
        // fields may contain embedded newlines (RFC 4180)
        var records = parseRecords(in: decodedContent)
        // When we stopped at the byte cap the final record may be cut in
        // half — it cannot be judged, so drop it
        if hitCap { records.removeLast() }

        guard !records.isEmpty else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "csv.issue.no_content".localized,
                suggestedActions: [],
                lastValidRowIndex: 0
            )
        }

        // The DuckDB sniffer picks the dialect — a semicolon-separated file
        // saved as .csv must be judged on its real delimiter, not a comma
        var effectiveDelimiter = delimiter
        if delimiter == "," {
            effectiveDelimiter = sniffDelimiter(in: records[0], fallback: delimiter)
        }

        // Get header column count
        let headerColumns = countColumns(inRecord: records[0], delimiter: effectiveDelimiter)
        guard headerColumns > 0 else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "csv.issue.header".localized,
                suggestedActions: [.openWithExternalTool],
                lastValidRowIndex: 0
            )
        }

        // Check each row starting from the last
        var issueType: CSVIntegrityCheckResult.IssueType? = nil
        var issueDescription: String? = nil
        var lastValidRowIndex = 0

        for (index, record) in records.dropFirst().enumerated() {
            let lineIndex = index  // 0-based index of data row (excluding header)

            // Check for unmatched quotes (record ended inside a quoted field)
            if hasUnmatchedQuotes(record) {
                issueType = .unmatchedQuotes
                issueDescription = "csv.issue.unmatched_quotes".localizedWithFormat(lineIndex + 2)
                lastValidRowIndex = lineIndex
                break
            }

            // Check column count
            let columnCount = countColumns(inRecord: record, delimiter: effectiveDelimiter)
            if columnCount != headerColumns {
                // If this is the last line, it might be truncated
                if lineIndex == records.count - 2 {
                    issueType = .truncatedLastRow
                    issueDescription = "csv.issue.truncated".localizedWithFormat(headerColumns, columnCount)
                    lastValidRowIndex = lineIndex
                } else {
                    issueType = .mismatchedColumns
                    issueDescription = "csv.issue.mismatch".localizedWithFormat(lineIndex + 2, headerColumns, columnCount)
                    lastValidRowIndex = lineIndex - 1
                }
                break
            }

            lastValidRowIndex = lineIndex + 1  // This row is valid
        }

        // Build suggested actions based on issue type
        var actions: [CSVRepairAction] = []

        if let issue = issueType {
            switch issue {
            case .truncatedLastRow:
                actions = [
                    .skipLastRow,
                    .ignoreAndLoad,
                    .openWithExternalTool
                ]
            case .mismatchedColumns, .unmatchedQuotes:
                actions = [
                    .ignoreAndLoad,
                    .openWithExternalTool,
                    .retryWithDifferentSettings
                ]
            case .encodingError, .emptyFile:
                actions = [.openWithExternalTool]
            }
        }

        return CSVIntegrityCheckResult(
            isValid: issueType == nil,
            issueType: issueType,
            issueDescription: issueDescription,
            suggestedActions: actions,
            lastValidRowIndex: lastValidRowIndex + 1  // Convert to 1-based (including header)
        )
    }

    /// Split content into records. A record boundary is any newline outside
    /// double quotes; newlines inside quotes stay within the record.
    static func parseRecords(in content: String) -> [String] {
        var records: [String] = []
        var current = ""
        var inQuotes = false
        var sawAnyContent = false

        for char in content {
            if inQuotes {
                current.append(char)
                if char == "\"" { inQuotes = false }
                continue
            }
            switch char {
            case "\"":
                inQuotes = true
                current.append(char)
                sawAnyContent = true
            case "\n", "\r":
                if sawAnyContent || !current.isEmpty {
                    records.append(current)
                }
                current = ""
                sawAnyContent = false
            default:
                current.append(char)
            }
        }
        if sawAnyContent || !current.isEmpty {
            records.append(current)
        }
        return records
    }

    /// Detect the dominant delimiter of a header record (outside quotes) so
    /// the checker agrees with DuckDB's dialect sniffing for .csv files.
    static func sniffDelimiter(in header: String, fallback: Character) -> Character {
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0, "|": 0]
        var inQuotes = false
        for char in header {
            if char == "\"" { inQuotes.toggle(); continue }
            if !inQuotes, counts[char] != nil { counts[char, default: 0] += 1 }
        }
        let best = counts.max { $0.value < $1.value }
        if let (delim, count) = best, count > 0 {
            return delim
        }
        return fallback
    }

    /// A record whose quotes never balanced leaves the parser inside a
    /// quoted field — persisted as a trailing lone quote here.
    private static func hasUnmatchedQuotes(_ record: String) -> Bool {
        var inQuotes = false
        for char in record where char == "\"" { inQuotes.toggle() }
        return inQuotes
    }

    /// Count columns in a CSV record (respects quotes)
    static func countColumns(inRecord record: String, delimiter: Character = ",") -> Int {
        var count = 0
        var inQuotes = false

        for char in record {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                count += 1
            }
        }

        // Add 1 for the last column (after the final delimiter, or if none)
        return count + 1
    }

    /// Get last valid row as a new string (for skipping truncated rows)
    static func createTruncatedContent(from url: URL, upToRow rowIndex: Int) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let records = parseRecords(in: content)
        let endIndex = min(rowIndex, records.count)
        return records[0..<endIndex].joined(separator: "\n")
    }
}
