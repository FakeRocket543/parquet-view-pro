// Data Table Component
// Extracted reusable data table view with sorting
// SM-5: UI Component

import SwiftUI

struct DataTableComponent: View {
    let columns: [String]
    let rows: [[Any?]]
    let sortColumn: String?
    let sortAscending: Bool
    let onSort: (String) -> Void

    private var stringRows: [[String]] {
        rows.map { row in
            row.map { cell in
                if let stringValue = cell as? String {
                    return stringValue
                } else if let intValue = cell as? Int {
                    return String(intValue)
                } else if let doubleValue = cell as? Double {
                    return String(doubleValue)
                } else if let boolValue = cell as? Bool {
                    return String(boolValue)
                } else if cell == nil {
                    return ""
                }
                return String(describing: cell ?? "")
            }
        }
    }

    var body: some View {
        ParquetTableView(
            columns: columns,
            rows: stringRows,
            onLoadMore: {},
            hasMoreData: false,
            isLoadingMore: false,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onSort: { columnName in
                onSort(columnName)
            }
        )
    }
}
