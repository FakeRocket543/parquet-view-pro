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
        self.onCopyCell = onCopyCell
        self.onCopyRow = onCopyRow
        self.onCopyColumn = onCopyColumn
        self.onCopyColumnNames = onCopyColumnNames
    }
    
    func makeNSView(context: Context) -> FreezeTableContainerView {
        let container = FreezeTableContainerView()
        
        // Create row numbers table (frozen) - Use custom class for right-click support
        let rowNumbersTable = RowNumberTableView()
        rowNumbersTable.onCopyRow = { [weak coordinator = context.coordinator] row in
            coordinator?.copyRow(at: row)
        }
        let rowNumbersScrollView = NSScrollView()
        rowNumbersScrollView.documentView = rowNumbersTable
        rowNumbersScrollView.hasVerticalScroller = false // Synced with data table
        rowNumbersScrollView.hasHorizontalScroller = false
        rowNumbersScrollView.borderType = .noBorder
        
        // Row number column
        let rowColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rowNumber"))
        rowColumn.title = "#"
        rowColumn.width = 60
        rowColumn.minWidth = 60
        rowColumn.maxWidth = 60
        rowColumn.resizingMask = []
        rowNumbersTable.addTableColumn(rowColumn)
        
        // Configure row numbers table
        rowNumbersTable.dataSource = context.coordinator
        rowNumbersTable.delegate = context.coordinator
        let rowHeaderView = ClickableTableHeaderView()
        rowHeaderView.onHeaderClick = { [weak coordinator = context.coordinator] in
            coordinator?.copyColumnNames()
        }
        rowNumbersTable.headerView = rowHeaderView
        rowNumbersTable.usesAlternatingRowBackgroundColors = true
        rowNumbersTable.intercellSpacing = NSSize(width: 1, height: 1)
        rowNumbersTable.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        rowNumbersTable.backgroundColor = NSColor.controlBackgroundColor
        rowNumbersTable.allowsColumnSelection = false
        rowNumbersTable.allowsEmptySelection = false
        
        // Create data table (scrollable)
        let dataTable = NSTableView()
        let dataScrollView = NSScrollView()
        dataScrollView.documentView = dataTable
        dataScrollView.hasVerticalScroller = true
        dataScrollView.hasHorizontalScroller = true
        dataScrollView.autohidesScrollers = false
        dataScrollView.borderType = .noBorder
        
        // Data columns
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
        let dataHeaderView = DataTableHeaderView()
        dataHeaderView.onCopyColumn = { [weak coordinator = context.coordinator] column in
            coordinator?.copyColumn(at: column)
        }
        dataTable.headerView = dataHeaderView
        dataTable.usesAlternatingRowBackgroundColors = true
        dataTable.allowsMultipleSelection = true
        dataTable.allowsColumnSelection = true
        dataTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        dataTable.intercellSpacing = NSSize(width: 1, height: 1)
        dataTable.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        dataTable.target = context.coordinator
        dataTable.doubleAction = #selector(Coordinator.tableDoubleClick(_:))
        
        // Enable context menu
        dataTable.menu = NSMenu()
        dataTable.menu?.delegate = context.coordinator
        
        // Store references in coordinator
        context.coordinator.rowNumbersTable = rowNumbersTable
        context.coordinator.dataTable = dataTable
        context.coordinator.rowNumbersScrollView = rowNumbersScrollView
        context.coordinator.dataScrollView = dataScrollView
        
        // Sync vertical scrolling
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.dataTableDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: dataScrollView.contentView
        )
        dataScrollView.contentView.postsBoundsChangedNotifications = true
        
        // Layout container
        container.addSubview(rowNumbersScrollView)
        container.addSubview(dataScrollView)
        
        // Auto Layout
        rowNumbersScrollView.translatesAutoresizingMaskIntoConstraints = false
        dataScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Row numbers on the left
            rowNumbersScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowNumbersScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            rowNumbersScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rowNumbersScrollView.widthAnchor.constraint(equalToConstant: 60),
            
            // Data table on the right
            dataScrollView.leadingAnchor.constraint(equalTo: rowNumbersScrollView.trailingAnchor),
            dataScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            dataScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dataScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func updateNSView(_ nsView: FreezeTableContainerView, context: Context) {
        // Update coordinator data
        context.coordinator.columns = columns
        context.coordinator.rows = rows
        context.coordinator.hasMoreData = hasMoreData
        context.coordinator.isLoadingMore = isLoadingMore
        
        // Reload both tables
        context.coordinator.rowNumbersTable?.reloadData()
        context.coordinator.dataTable?.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            columns: columns,
            rows: rows,
            hasMoreData: hasMoreData,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore,
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
        let onLoadMore: () -> Void
        let onCopyCell: ((Int, Int) -> Void)?
        let onCopyRow: ((Int) -> Void)?
        let onCopyColumn: ((Int) -> Void)?
        let onCopyColumnNames: (() -> Void)?
        
        weak var rowNumbersTable: NSTableView?
        weak var dataTable: NSTableView?
        weak var rowNumbersScrollView: NSScrollView?
        weak var dataScrollView: NSScrollView?
        
        private var isSyncingScroll = false
        
        init(
            columns: [String],
            rows: [[String]],
            hasMoreData: Bool,
            isLoadingMore: Bool,
            onLoadMore: @escaping () -> Void,
            onCopyCell: ((Int, Int) -> Void)?,
            onCopyRow: ((Int) -> Void)?,
            onCopyColumn: ((Int) -> Void)?,
            onCopyColumnNames: (() -> Void)?
        ) {
            self.columns = columns
            self.rows = rows
            self.hasMoreData = hasMoreData
            self.isLoadingMore = isLoadingMore
            self.onLoadMore = onLoadMore
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
            guard let identifier = tableColumn?.identifier else { return nil }
            
            // Row number column
            if identifier.rawValue == "rowNumber" {
                return "\(row + 1)"
            }
            
            // Data columns
            if let colIndexString = identifier.rawValue.split(separator: "_").last,
               let colIndex = Int(colIndexString),
               colIndex < rows[row].count {
                return rows[row][colIndex]
            }
            
            return nil
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let identifier = tableColumn?.identifier else { return nil }
            
            // Reuse or create cell view
            let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cellView == nil {
                cellView = NSTableCellView()
                cellView?.identifier = cellIdentifier
                
                let textField = NSTextField()
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.isEditable = false
                textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                textField.lineBreakMode = .byTruncatingTail
                textField.maximumNumberOfLines = 1
                
                cellView?.textField = textField
                cellView?.addSubview(textField)
                
                // Auto Layout
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
                ])
            }
            
            // Set cell content
            if identifier.rawValue == "rowNumber" {
                cellView?.textField?.stringValue = "\(row + 1)"
                cellView?.textField?.alignment = .center
                cellView?.textField?.textColor = .secondaryLabelColor
            } else if let colIndexString = identifier.rawValue.split(separator: "_").last,
                      let colIndex = Int(colIndexString),
                      colIndex < rows[row].count {
                let value = rows[row][colIndex]
                cellView?.textField?.stringValue = value
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
            guard let tableView = notification.object as? NSTableView else { return }
            
            // Sync selection between row numbers and data table
            if tableView == rowNumbersTable, let dataTable = dataTable {
                dataTable.selectRowIndexes(tableView.selectedRowIndexes, byExtendingSelection: false)
            } else if tableView == dataTable, let rowNumbersTable = rowNumbersTable {
                rowNumbersTable.selectRowIndexes(tableView.selectedRowIndexes, byExtendingSelection: false)
            }
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
                    let rowData = rows[rowIndex].joined(separator: "\t")
                    textToCopy += rowData + "\n"
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
        
        // MARK: - Scroll Synchronization
        
        @objc func dataTableDidScroll(_ notification: Notification) {
            guard !isSyncingScroll,
                  let dataScrollView = dataScrollView,
                  let rowNumbersScrollView = rowNumbersScrollView else { return }
            
            isSyncingScroll = true
            
            // Sync vertical scroll
            let dataOrigin = dataScrollView.contentView.bounds.origin
            var rowNumbersOrigin = rowNumbersScrollView.contentView.bounds.origin
            rowNumbersOrigin.y = dataOrigin.y
            rowNumbersScrollView.contentView.scroll(to: rowNumbersOrigin)
            rowNumbersScrollView.reflectScrolledClipView(rowNumbersScrollView.contentView)
            
            isSyncingScroll = false
            
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

// MARK: - Container View

class FreezeTableContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Custom Table Views

// Custom table view for row numbers with right-click support
class RowNumberTableView: NSTableView {
    var onCopyRow: ((Int) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        
        if row >= 0 {
            // Select the row
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
            // Show menu
            let menu = NSMenu()
            let copyItem = NSMenuItem(title: "Copy Row", action: #selector(copyRowAction), keyEquivalent: "")
            copyItem.target = self
            copyItem.representedObject = row
            menu.addItem(copyItem)
            
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    @objc func copyRowAction(_ sender: NSMenuItem) {
        if let row = sender.representedObject as? Int {
            onCopyRow?(row)
        }
    }
}

// MARK: - Clickable Table Header View

// Header view for row numbers table ("#")
class ClickableTableHeaderView: NSTableHeaderView {
    var onHeaderClick: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onHeaderClick?()
        }
        super.mouseDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Show context menu on right-click
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "Copy Column Names", action: #selector(copyHeaderAction), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        
        // Show menu at click location
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        // Also handle regular menu requests
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "Copy Column Names", action: #selector(copyHeaderAction), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        return menu
    }
    
    @objc func copyHeaderAction() {
        onHeaderClick?()
    }
}

// Header view for data table columns with per-column right-click
class DataTableHeaderView: NSTableHeaderView {
    var onCopyColumn: ((Int) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)
        
        if column >= 0, let tableView = self.tableView {
            // Select the column
            tableView.selectColumnIndexes(IndexSet(integer: column), byExtendingSelection: false)
            
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
