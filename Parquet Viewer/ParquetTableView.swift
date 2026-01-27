//
// ParquetTableView.swift
// NSTableView-based data table with TRUE freeze pane support
//

import SwiftUI
import AppKit

/// Custom NSTableView wrapper with freeze pane for row numbers
struct ParquetTableView: NSViewRepresentable {
    // Data
    let columns: [String]
    let rows: [[String]]
    
    // Configuration
    let onLoadMore: () -> Void
    let hasMoreData: Bool
    let isLoadingMore: Bool
    
    // Sorting
    let sortColumn: String?
    let sortAscending: Bool
    let onSort: ((String) -> Void)?
    
    // Font size from settings
    @AppStorage("tableFontSize") private var tableFontSize: Double = 13.0
    
    // Copy handlers
    let onCopyCell: ((Int, Int) -> Void)?
    let onCopyRow: ((Int) -> Void)?
    let onCopyColumn: ((Int) -> Void)?
    let onCopyColumnNames: (() -> Void)?
    
    init(
        columns: [String],
        rows: [[String]],
        onLoadMore: @escaping () -> Void = {},
        hasMoreData: Bool = false,
        isLoadingMore: Bool = false,
        sortColumn: String? = nil,
        sortAscending: Bool = true,
        onSort: ((String) -> Void)? = nil,
        onCopyCell: ((Int, Int) -> Void)? = nil,
        onCopyRow: ((Int) -> Void)? = nil,
        onCopyColumn: ((Int) -> Void)? = nil,
        onCopyColumnNames: (() -> Void)? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.onLoadMore = onLoadMore
        self.hasMoreData = hasMoreData
        self.isLoadingMore = isLoadingMore
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.onSort = onSort
        self.onCopyCell = onCopyCell
        self.onCopyRow = onCopyRow
        self.onCopyColumn = onCopyColumn
        self.onCopyColumnNames = onCopyColumnNames
    }
    
    func makeNSView(context: Context) -> NSView {
        // Create container with frozen left column (row numbers) and scrollable right section (data)
        let container = NSView()

        // LEFT: Frozen row numbers table
        let rowNumberTable = NSTableView()
        let rowNumberScrollView = NSScrollView()
        rowNumberScrollView.documentView = rowNumberTable
        rowNumberScrollView.hasVerticalScroller = false
        rowNumberScrollView.hasHorizontalScroller = false

        // Add only row number column
        let rowNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_rownum"))
        rowNumberColumn.title = "#"
        rowNumberColumn.width = 60
        rowNumberColumn.minWidth = 60
        rowNumberColumn.maxWidth = 60
        rowNumberColumn.resizingMask = []
        rowNumberTable.addTableColumn(rowNumberColumn)

        // Configure row number table
        rowNumberTable.dataSource = context.coordinator
        rowNumberTable.delegate = context.coordinator
        rowNumberTable.headerView = NSTableHeaderView()
        rowNumberTable.usesAlternatingRowBackgroundColors = true
        rowNumberTable.intercellSpacing = NSSize(width: 1, height: 1)
        rowNumberTable.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]

        // RIGHT: Scrollable data table
        let dataTable = NSTableView()
        let dataScrollView = NSScrollView()
        dataScrollView.documentView = dataTable
        dataScrollView.hasVerticalScroller = true
        dataScrollView.hasHorizontalScroller = true
        dataScrollView.autohidesScrollers = false

        // Add all data columns (all columns from data)
        for (index, columnName) in columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            column.title = columnName
            column.width = 150
            column.minWidth = 50
            column.maxWidth = 500
            dataTable.addTableColumn(column)
        }

        // Configure data table
        dataTable.dataSource = context.coordinator
        dataTable.delegate = context.coordinator
        let headerView = DataTableHeaderView()
        headerView.onCopyColumn = { [weak coordinator = context.coordinator] column in
            coordinator?.copyColumn(at: column)
        }
        headerView.onSortColumn = { [weak coordinator = context.coordinator] column in
            coordinator?.handleSort(at: column)
        }
        dataTable.headerView = headerView
        dataTable.usesAlternatingRowBackgroundColors = true
        dataTable.allowsMultipleSelection = true
        dataTable.allowsColumnSelection = false  // Disable column selection (view-based tables don't support it)
        dataTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        dataTable.intercellSpacing = NSSize(width: 1, height: 1)
        dataTable.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        dataTable.target = context.coordinator
        dataTable.doubleAction = #selector(Coordinator.tableDoubleClick(_:))

        // Enable context menu
        dataTable.menu = NSMenu()
        dataTable.menu?.delegate = context.coordinator

        // Synchronize vertical scrolling between row numbers and data tables
        let clipView = dataScrollView.contentView
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak rowNumberScrollView] _ in
            if let rowNumberClipView = rowNumberScrollView?.contentView {
                var bounds = rowNumberClipView.bounds
                bounds.origin.y = clipView.bounds.origin.y
                rowNumberClipView.bounds = bounds
            }
        }

        // Layout: HStack with frozen left and scrollable right
        container.addSubview(rowNumberScrollView)
        container.addSubview(dataScrollView)

        rowNumberScrollView.translatesAutoresizingMaskIntoConstraints = false
        dataScrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rowNumberScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowNumberScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            rowNumberScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rowNumberScrollView.widthAnchor.constraint(equalToConstant: 60),

            dataScrollView.leadingAnchor.constraint(equalTo: rowNumberScrollView.trailingAnchor),
            dataScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dataScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            dataScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Store references in coordinator
        context.coordinator.rowNumbersTable = rowNumberTable
        context.coordinator.rowNumbersScrollView = rowNumberScrollView
        context.coordinator.dataTable = dataTable
        context.coordinator.dataScrollView = dataScrollView

        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update coordinator data
        context.coordinator.columns = columns
        context.coordinator.rows = rows
        context.coordinator.hasMoreData = hasMoreData
        context.coordinator.isLoadingMore = isLoadingMore
        context.coordinator.fontSize = tableFontSize
        context.coordinator.sortColumn = sortColumn
        context.coordinator.sortAscending = sortAscending

        // Reload both tables
        context.coordinator.rowNumbersTable?.reloadData()
        context.coordinator.dataTable?.reloadData()
        
        // Update header sort indicators
        if let dataTable = context.coordinator.dataTable {
            for (index, columnName) in columns.enumerated() {
                if let tableColumn = dataTable.tableColumns.first(where: { $0.identifier.rawValue == "col_\(index)" }) {
                    if columnName == sortColumn {
                        tableColumn.title = sortAscending ? "\(columnName) ▲" : "\(columnName) ▼"
                    } else {
                        tableColumn.title = columnName
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            columns: columns,
            rows: rows,
            hasMoreData: hasMoreData,
            isLoadingMore: isLoadingMore,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onLoadMore: onLoadMore,
            onSort: onSort,
            onCopyCell: onCopyCell,
            onCopyRow: onCopyRow,
            onCopyColumn: onCopyColumn,
            onCopyColumnNames: onCopyColumnNames
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        var columns: [String]
        var rows: [[String]]
        var hasMoreData: Bool
        var isLoadingMore: Bool
        var fontSize: Double = 13.0 // Font size for table cells
        var sortColumn: String?
        var sortAscending: Bool = true
        let onLoadMore: () -> Void
        let onSort: ((String) -> Void)?
        let onCopyCell: ((Int, Int) -> Void)?
        let onCopyRow: ((Int) -> Void)?
        let onCopyColumn: ((Int) -> Void)?
        let onCopyColumnNames: (() -> Void)?

        weak var rowNumbersTable: NSTableView?
        weak var rowNumbersScrollView: NSScrollView?
        weak var dataTable: NSTableView?
        weak var dataScrollView: NSScrollView?
        
        init(
            columns: [String],
            rows: [[String]],
            hasMoreData: Bool,
            isLoadingMore: Bool,
            sortColumn: String?,
            sortAscending: Bool,
            onLoadMore: @escaping () -> Void,
            onSort: ((String) -> Void)?,
            onCopyCell: ((Int, Int) -> Void)?,
            onCopyRow: ((Int) -> Void)?,
            onCopyColumn: ((Int) -> Void)?,
            onCopyColumnNames: (() -> Void)?
        ) {
            self.columns = columns
            self.rows = rows
            self.hasMoreData = hasMoreData
            self.isLoadingMore = isLoadingMore
            self.sortColumn = sortColumn
            self.sortAscending = sortAscending
            self.onLoadMore = onLoadMore
            self.onSort = onSort
            self.onCopyCell = onCopyCell
            self.onCopyRow = onCopyRow
            self.onCopyColumn = onCopyColumn
            self.onCopyColumnNames = onCopyColumnNames
            super.init()
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return rows.count
        }
        
        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            guard row < rows.count else { return nil }

            if tableView == rowNumbersTable {
                // Row numbers table: generate row number
                return String(row + 1)
            } else {
                // Data table: return data column
                guard let identifier = tableColumn?.identifier else { return nil }
                if let colIndexString = identifier.rawValue.split(separator: "_").last,
                   let colIndex = Int(colIndexString) {
                    if colIndex < rows[row].count {
                        return rows[row][colIndex]
                    }
                }
            }

            return nil
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < rows.count else { return nil }

            // Reuse or create cell view
            let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

            if cellView == nil {
                let newCellView = NSTableCellView()
                newCellView.identifier = cellIdentifier

                let textField = NSTextField()
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.isEditable = false
                textField.lineBreakMode = .byTruncatingTail
                textField.maximumNumberOfLines = 1

                newCellView.textField = textField
                newCellView.addSubview(textField)

                // Auto Layout
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: newCellView.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: newCellView.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: newCellView.centerYAnchor)
                ])

                cellView = newCellView
            }

            if tableView == rowNumbersTable {
                // Row numbers table: generate and display row number
                cellView?.textField?.stringValue = String(row + 1)
                cellView?.textField?.alignment = .center
                cellView?.textField?.textColor = .secondaryLabelColor
                cellView?.textField?.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            } else {
                // Data table: display data column
                guard let identifier = tableColumn?.identifier,
                      let colIndexString = identifier.rawValue.split(separator: "_").last,
                      let colIndex = Int(colIndexString),
                      colIndex < rows[row].count else { return cellView }

                let value = rows[row][colIndex]
                cellView?.textField?.stringValue = value

                // Apply font size (from settings)
                cellView?.textField?.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                cellView?.textField?.alignment = .left

                // Color coding based on value type
                if value == "NULL" {
                    cellView?.textField?.textColor = .secondaryLabelColor
                } else if value == "true" || value == "false" {
                    cellView?.textField?.textColor = .systemBlue
                } else if Double(value) != nil {
                    cellView?.textField?.textColor = .systemPurple
                } else {
                    cellView?.textField?.textColor = .labelColor
                }
            }

            return cellView
        }
        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 28 // Match SwiftUI version row height
        }
        
        // MARK: - Selection & Context Menu
        
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            return true
        }
        
        // Click handling for row selection
        func tableViewSelectionDidChange(_ notification: Notification) {
            // Selection handled automatically by single table view
        }
        
        // MARK: - NSMenuDelegate
        
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            
            // Copy menu item
            let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelection), keyEquivalent: "c")
            copyItem.keyEquivalentModifierMask = .command
            copyItem.target = self
            menu.addItem(copyItem)
        }
        
        // Double click handler
        @objc func tableDoubleClick(_ sender: Any) {
            // Future: implement double-click behavior
        }
        
        // Handle header click for column selection
        func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
            guard tableView == dataTable else { return }
            
            // Select entire column
            tableView.selectColumnIndexes(IndexSet(integer: tableView.column(withIdentifier: tableColumn.identifier)), byExtendingSelection: false)
        }
        
        @objc func copySelection() {
            guard let dataTable = dataTable else { return }

            let selectedRows = dataTable.selectedRowIndexes
            let selectedColumns = dataTable.selectedColumnIndexes

            var textToCopy = ""

            // CRITICAL: Check rows first! (User usually selects rows, not columns)
            // Only treat as column selection if ONLY columns are selected (no rows)
            if selectedRows.count > 0 && selectedColumns.count == 0 {
                // Copy selected rows (most common case)
                for rowIndex in selectedRows.sorted() {
                    guard rowIndex < rows.count else { continue }
                    let rowData = rows[rowIndex]
                    textToCopy += rowData.joined(separator: "\t") + "\n"
                }
            } else if selectedColumns.count > 0 && selectedRows.count == 0 {
                // Copy selected columns (explicit column selection)
                for columnIndex in selectedColumns.sorted() {
                    guard columnIndex < columns.count else { continue }

                    // Copy column name first
                    textToCopy += columns[columnIndex] + "\n"

                    // Copy all rows in this column
                    for rowIndex in 0..<rows.count {
                        if rowIndex < rows.count && columnIndex < rows[rowIndex].count {
                            textToCopy += rows[rowIndex][columnIndex] + "\n"
                        }
                    }
                    textToCopy += "\n"
                }
            } else if selectedRows.count > 0 && selectedColumns.count > 0 {
                // Both rows and columns selected - copy range
                for rowIndex in selectedRows.sorted() {
                    guard rowIndex < rows.count else { continue }
                    var rowData: [String] = []
                    for columnIndex in selectedColumns.sorted() {
                        if columnIndex < rows[rowIndex].count {
                            rowData.append(rows[rowIndex][columnIndex])
                        }
                    }
                    textToCopy += rowData.joined(separator: "\t") + "\n"
                }
            }

            // Copy to clipboard
            if !textToCopy.isEmpty {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textToCopy, forType: .string)
            }
        }
        
        func copyColumnNames() {
            let columnNames = columns.joined(separator: "\t")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(columnNames, forType: .string)
        }

        func copyRow(at index: Int) {
            guard index < rows.count else { return }
            let rowData = rows[index].joined(separator: "\t")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(rowData, forType: .string)
        }

        func copyColumn(at index: Int) {
            guard index < columns.count else { return }

            var textToCopy = ""
            // Copy column name first
            textToCopy += columns[index] + "\n"

            // Copy all rows in this column
            for rowIndex in 0..<rows.count {
                if rowIndex < rows.count && index < rows[rowIndex].count {
                    textToCopy += rows[rowIndex][index] + "\n"
                }
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(textToCopy, forType: .string)
        }
        
        func handleSort(at index: Int) {
            guard index < columns.count else { return }
            let columnName = columns[index]
            onSort?(columnName)
        }
        
        // MARK: - Pagination

        @objc func dataTableDidScroll(_ notification: Notification) {
            // Check for pagination
            if let tableView = dataTable, hasMoreData, !isLoadingMore {
                let visibleRows = tableView.rows(in: tableView.visibleRect)
                let lastVisibleRow = visibleRows.upperBound - 1

                // Load more when near bottom (within 10 rows)
                if lastVisibleRow >= rows.count - 10 {
                    onLoadMore()
                }
            }
        }
    }
}

// MARK: - Table Header View

// Header view for data table columns with per-column right-click
class DataTableHeaderView: NSTableHeaderView {
    var onCopyColumn: ((Int) -> Void)?
    var onSortColumn: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)
        
        // Check if clicking on column resize area (near the edge)
        if self.tableView != nil, column >= 0 {
            let columnRect = headerRect(ofColumn: column)
            let rightEdge = columnRect.maxX
            let isNearRightEdge = abs(point.x - rightEdge) < 5 // 5 pixels tolerance
            
            // If near edge, let the default resize behavior handle it
            if isNearRightEdge {
                super.mouseDown(with: event)
                return
            }
            
            // Only trigger sort on actual column header click (not drag)
            if event.clickCount == 1 {
                onSortColumn?(column)
            }
        }
        
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)

        if column >= 0, let tableView = self.tableView, column < tableView.tableColumns.count {
            // Get column name
            let columnName = tableView.tableColumns[column].title

            // Show menu
            let menu = NSMenu()
            let copyItem = NSMenuItem(title: "Copy Column \"\(columnName)\"", action: #selector(copyColumnAction), keyEquivalent: "")
            copyItem.target = self
            copyItem.representedObject = column
            menu.addItem(copyItem)

            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    @objc func copyColumnAction(_ sender: NSMenuItem) {
        if let column = sender.representedObject as? Int {
            onCopyColumn?(column)
        }
    }
}

// MARK: - Preview

#Preview {
    ParquetTableView(
        columns: ["ID", "Name", "Age", "City"],
        rows: [
            ["1", "Alice", "30", "New York"],
            ["2", "Bob", "25", "Los Angeles"],
            ["3", "Charlie", "35", "Chicago"]
        ]
    )
    .frame(width: 800, height: 600)
}
