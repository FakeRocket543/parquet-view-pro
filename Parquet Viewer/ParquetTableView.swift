//
// ParquetTableView.swift
// NSTableView-based data table with row numbers as first column
//

import SwiftUI
import AppKit

/// Single NSTableView with row number as first column — guarantees perfect alignment
struct ParquetTableView: NSViewRepresentable {
    let columns: [String]
    let rows: [[String]]
    let onLoadMore: () -> Void
    let hasMoreData: Bool
    let isLoadingMore: Bool
    let sortColumn: String?
    let sortAscending: Bool
    let onSort: ((String) -> Void)?
    @AppStorage("tableFontSize") private var tableFontSize: Double = 13.0
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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false

        // Row number column (#)
        let rowNumCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_rownum"))
        rowNumCol.title = "#"
        rowNumCol.width = 60
        rowNumCol.minWidth = 40
        rowNumCol.maxWidth = 80
        rowNumCol.resizingMask = []
        tableView.addTableColumn(rowNumCol)

        // Data columns
        for (index, name) in columns.enumerated() {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            col.title = name
            col.width = 150
            col.minWidth = 50
            col.maxWidth = 500
            tableView.addTableColumn(col)
        }

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        let headerView = DataTableHeaderView()
        headerView.onCopyColumn = { [weak coordinator = context.coordinator] col in
            coordinator?.copyColumn(at: col)
        }
        headerView.onSortColumn = { [weak coordinator = context.coordinator] col in
            coordinator?.handleSort(at: col)
        }
        tableView.headerView = headerView
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.intercellSpacing = NSSize(width: 1, height: 1)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.tableDoubleClick(_:))
        tableView.menu = NSMenu()
        tableView.menu?.delegate = context.coordinator

        context.coordinator.dataTable = tableView
        context.coordinator.dataScrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.columns = columns
        context.coordinator.rows = rows
        context.coordinator.hasMoreData = hasMoreData
        context.coordinator.isLoadingMore = isLoadingMore
        context.coordinator.fontSize = tableFontSize
        context.coordinator.sortColumn = sortColumn
        context.coordinator.sortAscending = sortAscending

        context.coordinator.dataTable?.reloadData()

        // Update sort indicators (skip col_rownum at index 0)
        if let table = context.coordinator.dataTable {
            for (index, name) in columns.enumerated() {
                let id = NSUserInterfaceItemIdentifier("col_\(index)")
                if let tc = table.tableColumns.first(where: { $0.identifier == id }) {
                    tc.title = name == sortColumn
                        ? (sortAscending ? "\(name) ▲" : "\(name) ▼")
                        : name
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            columns: columns, rows: rows,
            hasMoreData: hasMoreData, isLoadingMore: isLoadingMore,
            sortColumn: sortColumn, sortAscending: sortAscending,
            onLoadMore: onLoadMore, onSort: onSort,
            onCopyCell: onCopyCell, onCopyRow: onCopyRow,
            onCopyColumn: onCopyColumn, onCopyColumnNames: onCopyColumnNames
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        var columns: [String]
        var rows: [[String]]
        var hasMoreData: Bool
        var isLoadingMore: Bool
        var fontSize: Double = 13.0
        var sortColumn: String?
        var sortAscending: Bool = true
        let onLoadMore: () -> Void
        let onSort: ((String) -> Void)?
        let onCopyCell: ((Int, Int) -> Void)?
        let onCopyRow: ((Int) -> Void)?
        let onCopyColumn: ((Int) -> Void)?
        let onCopyColumnNames: (() -> Void)?

        weak var dataTable: NSTableView?
        weak var dataScrollView: NSScrollView?

        init(
            columns: [String], rows: [[String]],
            hasMoreData: Bool, isLoadingMore: Bool,
            sortColumn: String?, sortAscending: Bool,
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

        // MARK: - DataSource

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        // MARK: - Delegate

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < rows.count, let identifier = tableColumn?.identifier else { return nil }

            let cellId = NSUserInterfaceItemIdentifier("DataCell")
            var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView

            if cell == nil {
                let c = NSTableCellView()
                c.identifier = cellId
                let tf = NSTextField()
                tf.isBordered = false
                tf.backgroundColor = .clear
                tf.isEditable = false
                tf.lineBreakMode = .byTruncatingTail
                tf.maximumNumberOfLines = 1
                c.textField = tf
                c.addSubview(tf)
                tf.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8),
                    tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -8),
                    tf.centerYAnchor.constraint(equalTo: c.centerYAnchor)
                ])
                cell = c
            }

            let tf = cell?.textField
            tf?.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

            if identifier.rawValue == "col_rownum" {
                tf?.stringValue = String(row + 1)
                tf?.alignment = .center
                tf?.textColor = .secondaryLabelColor
            } else if let idxStr = identifier.rawValue.split(separator: "_").last,
                      let colIdx = Int(idxStr), colIdx < rows[row].count {
                let value = rows[row][colIdx]
                tf?.stringValue = value
                tf?.alignment = .left
                if value == "NULL" { tf?.textColor = .secondaryLabelColor }
                else if value == "true" || value == "false" { tf?.textColor = .systemBlue }
                else if Double(value) != nil { tf?.textColor = .systemPurple }
                else { tf?.textColor = .labelColor }
            }

            return cell
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 28 }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

        func tableViewSelectionDidChange(_ notification: Notification) {}

        // MARK: - Context Menu

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            let item = NSMenuItem(title: "Copy", action: #selector(copySelection), keyEquivalent: "c")
            item.keyEquivalentModifierMask = .command
            item.target = self
            menu.addItem(item)
        }

        @objc func tableDoubleClick(_ sender: Any) {}

        func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
            guard tableColumn.identifier.rawValue != "col_rownum" else { return }
            tableView.selectColumnIndexes(
                IndexSet(integer: tableView.column(withIdentifier: tableColumn.identifier)),
                byExtendingSelection: false
            )
        }

        // MARK: - Copy

        @objc func copySelection() {
            guard let table = dataTable else { return }
            let selectedRows = table.selectedRowIndexes
            let selectedCols = table.selectedColumnIndexes
            var text = ""

            if selectedRows.count > 0 && selectedCols.count == 0 {
                for r in selectedRows.sorted() {
                    guard r < rows.count else { continue }
                    text += rows[r].joined(separator: "\t") + "\n"
                }
            } else if selectedCols.count > 0 && selectedRows.count == 0 {
                for c in selectedCols.sorted() {
                    let dataIdx = dataColumnIndex(fromTableColumn: c)
                    guard let di = dataIdx, di < columns.count else { continue }
                    text += columns[di] + "\n"
                    for r in 0..<rows.count where di < rows[r].count {
                        text += rows[r][di] + "\n"
                    }
                    text += "\n"
                }
            } else if selectedRows.count > 0 && selectedCols.count > 0 {
                for r in selectedRows.sorted() {
                    guard r < rows.count else { continue }
                    var rd: [String] = []
                    for c in selectedCols.sorted() {
                        if let di = dataColumnIndex(fromTableColumn: c), di < rows[r].count {
                            rd.append(rows[r][di])
                        }
                    }
                    text += rd.joined(separator: "\t") + "\n"
                }
            }

            if !text.isEmpty {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
            }
        }

        func copyColumnNames() {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(columns.joined(separator: "\t"), forType: .string)
        }

        func copyRow(at index: Int) {
            guard index < rows.count else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(rows[index].joined(separator: "\t"), forType: .string)
        }

        func copyColumn(at tableColIndex: Int) {
            guard let di = dataColumnIndex(fromTableColumn: tableColIndex), di < columns.count else { return }
            var text = columns[di] + "\n"
            for r in 0..<rows.count where di < rows[r].count {
                text += rows[r][di] + "\n"
            }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }

        func handleSort(at tableColIndex: Int) {
            guard let di = dataColumnIndex(fromTableColumn: tableColIndex), di < columns.count else { return }
            onSort?(columns[di])
        }

        // MARK: - Helpers

        /// Convert table column index to data column index (skipping row number column)
        private func dataColumnIndex(fromTableColumn tableCol: Int) -> Int? {
            guard let table = dataTable, tableCol < table.tableColumns.count else { return nil }
            let id = table.tableColumns[tableCol].identifier.rawValue
            guard id != "col_rownum",
                  let idxStr = id.split(separator: "_").last,
                  let idx = Int(idxStr) else { return nil }
            return idx
        }

        // MARK: - Pagination

        @objc func dataTableDidScroll(_ notification: Notification) {
            if let table = dataTable, hasMoreData, !isLoadingMore {
                let visible = table.rows(in: table.visibleRect)
                if visible.upperBound - 1 >= rows.count - 10 {
                    onLoadMore()
                }
            }
        }
    }
}

// MARK: - Table Header View

class DataTableHeaderView: NSTableHeaderView {
    var onCopyColumn: ((Int) -> Void)?
    var onSortColumn: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)

        if self.tableView != nil, column >= 0 {
            // Skip sort for row number column
            if let tv = self.tableView, tv.tableColumns[column].identifier.rawValue == "col_rownum" {
                super.mouseDown(with: event)
                return
            }
            let rect = headerRect(ofColumn: column)
            if abs(point.x - rect.maxX) < 5 {
                super.mouseDown(with: event)
                return
            }
            if event.clickCount == 1 { onSortColumn?(column) }
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)

        if column >= 0, let tv = self.tableView, column < tv.tableColumns.count {
            let tc = tv.tableColumns[column]
            guard tc.identifier.rawValue != "col_rownum" else { return }
            let menu = NSMenu()
            let item = NSMenuItem(title: "Copy Column \"\(tc.title)\"", action: #selector(copyColumnAction), keyEquivalent: "")
            item.target = self
            item.representedObject = column
            menu.addItem(item)
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    @objc func copyColumnAction(_ sender: NSMenuItem) {
        if let col = sender.representedObject as? Int { onCopyColumn?(col) }
    }
}

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
