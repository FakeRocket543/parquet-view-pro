//
// ParquetTableView.swift
// NSTableView-based data table with native freeze pane support
//

import SwiftUI
import AppKit

/// NSTableView wrapper providing native freeze pane functionality
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
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.intercellSpacing = NSSize(width: 1, height: 1)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        
        // Row number column (frozen)
        let rowNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rowNumber"))
        rowNumberColumn.title = "#"
        rowNumberColumn.width = 60
        rowNumberColumn.minWidth = 60
        rowNumberColumn.maxWidth = 60
        rowNumberColumn.resizingMask = [] // Cannot be resized
        tableView.addTableColumn(rowNumberColumn)
        
        // Data columns
        for (index, columnName) in columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            column.title = columnName
            column.width = 150
            column.minWidth = 50
            column.maxWidth = 500
            tableView.addTableColumn(column)
        }
        
        // Configure scroll view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        // Observe scrolling for pagination
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
        
        // Store references in coordinator
        context.coordinator.tableView = tableView
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        
        // Update coordinator data
        context.coordinator.columns = columns
        context.coordinator.rows = rows
        context.coordinator.hasMoreData = hasMoreData
        context.coordinator.isLoadingMore = isLoadingMore
        
        // Reload table
        tableView.reloadData()
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
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var columns: [String]
        var rows: [[String]]
        var hasMoreData: Bool
        var isLoadingMore: Bool
        let onLoadMore: () -> Void
        let onCopyCell: ((Int, Int) -> Void)?
        let onCopyRow: ((Int) -> Void)?
        let onCopyColumn: ((Int) -> Void)?
        let onCopyColumnNames: (() -> Void)?
        
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        
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
        
        // MARK: - Scrolling for Pagination
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let tableView = tableView,
                  hasMoreData,
                  !isLoadingMore else { return }
            
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            let lastVisibleRow = visibleRows.upperBound - 1
            
            // Load more when near bottom (within 10 rows)
            if lastVisibleRow >= rows.count - 10 {
                onLoadMore()
            }
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
