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
            return "載入檔案（忽略錯誤）"
        case .skipLastRow:
            return "跳過最後一行並載入"
        case .openWithExternalTool:
            return "用外部編輯器修復"
        case .retryWithDifferentSettings:
            return "使用不同解析設定"
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

    /// Check CSV file integrity
    static func check(url: URL) -> CSVIntegrityCheckResult {
        // First check if file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "檔案不存在",
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
                issueDescription: "檔案為空",
                suggestedActions: [],
                lastValidRowIndex: 0
            )
        }

        // Read file content
        let content: String
        if let utf8Content = try? String(contentsOf: url, encoding: .utf8) {
            content = utf8Content
        } else if let utf16Content = try? String(contentsOf: url, encoding: .utf16) {
            content = utf16Content
        } else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .encodingError,
                issueDescription: "無法讀取檔案編碼",
                suggestedActions: [.openWithExternalTool],
                lastValidRowIndex: 0
            )
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "檔案沒有內容",
                suggestedActions: [],
                lastValidRowIndex: 0
            )
        }

        // Get header column count
        let headerColumns = countColumns(inLine: lines[0])
        guard headerColumns > 0 else {
            return CSVIntegrityCheckResult(
                isValid: false,
                issueType: .emptyFile,
                issueDescription: "無法解析標題行",
                suggestedActions: [.openWithExternalTool],
                lastValidRowIndex: 0
            )
        }

        // Check each row starting from the last
        var issueType: CSVIntegrityCheckResult.IssueType? = nil
        var issueDescription: String? = nil
        var lastValidRowIndex = 0

        for (index, line) in lines.dropFirst().enumerated() {
            let lineIndex = index  // 0-based index of data row (excluding header)

            // Check for unmatched quotes
            let quoteCount = line.components(separatedBy: "\"").count - 1
            if quoteCount % 2 != 0 {
                issueType = .unmatchedQuotes
                issueDescription = "第 \(lineIndex + 2) 行引號不配對"
                lastValidRowIndex = lineIndex
                break
            }

            // Check column count
            let columnCount = countColumns(inLine: line)
            if columnCount != headerColumns {
                // If this is the last line, it might be truncated
                if lineIndex == lines.count - 2 {
                    issueType = .truncatedLastRow
                    issueDescription = "最後一行被截斷（預期 \(headerColumns) 欄，實際 \(columnCount) 欄）"
                    lastValidRowIndex = lineIndex
                } else {
                    issueType = .mismatchedColumns
                    issueDescription = "第 \(lineIndex + 2) 行欄位數量不符（預期 \(headerColumns) 欄，實際 \(columnCount) 欄）"
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

    /// Count columns in a CSV line (respects quotes)
    private static func countColumns(inLine line: String) -> Int {
        var count = 0
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                count += 1
            }
        }

        // Add 1 for the last column (after the final comma, or if no commas)
        return count + 1
    }

    /// Get last valid row as a new string (for skipping truncated rows)
    static func createTruncatedContent(from url: URL, upToRow rowIndex: Int) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        let endIndex = min(rowIndex + 1, lines.count)  // +1 because rowIndex includes header
        return lines[0..<endIndex].joined(separator: "\n")
    }
}
