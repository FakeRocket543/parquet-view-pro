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
    /// Absolute index of the first displayed row (0-based) so the row-number
    /// gutter stays correct after Jump-to-Row / pagination
    var startRow: Int = 0
    /// Manager's one-shot anchor: nil = semantic reset, n = index shift
    var pendingRowShift: Int? = nil
    /// Reliable reload fingerprint (hash-free)
    var dataVersion: UInt64 = 0
    var onLoadMore: () -> Void
    var onLoadPrevious: () -> Void = {}
    var hasMoreData: Bool = false
    var hasPreviousData: Bool = false
    let isLoadingMore: Bool
    let sortColumn: String?
    let sortAscending: Bool
    var onSort: ((String) -> Void)?
    /// Explicit-direction sort (header context menu); falls back to onSort
    var onSortDirected: ((String, Bool) -> Void)? = nil
    @AppStorage("tableFontSize") private var tableFontSize: Double = 13.0
    var onCopyCell: ((Int, Int) -> Void)?
    var onCopyRow: ((Int) -> Void)?
    var onCopyColumn: ((Int) -> Void)?
    var onCopyColumnNames: (() -> Void)?

    init(
        columns: [String],
        rows: [[String]],
        startRow: Int = 0,
        pendingRowShift: Int? = nil,
        dataVersion: UInt64 = 0,
        onLoadMore: @escaping () -> Void = {},
        onLoadPrevious: @escaping () -> Void = {},
        hasMoreData: Bool = false,
        hasPreviousData: Bool = false,
        isLoadingMore: Bool = false,
        sortColumn: String? = nil,
        sortAscending: Bool = true,
        onSort: ((String) -> Void)? = nil,
        onSortDirected: ((String, Bool) -> Void)? = nil,
        onCopyCell: ((Int, Int) -> Void)? = nil,
        onCopyRow: ((Int) -> Void)? = nil,
        onCopyColumn: ((Int) -> Void)? = nil,
        onCopyColumnNames: (() -> Void)? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.startRow = startRow
        self.pendingRowShift = pendingRowShift
        self.dataVersion = dataVersion
        self.onLoadMore = onLoadMore
        self.onLoadPrevious = onLoadPrevious
        self.hasMoreData = hasMoreData
        self.hasPreviousData = hasPreviousData
        self.isLoadingMore = isLoadingMore
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.onSort = onSort
        self.onSortDirected = onSortDirected
        self.onCopyCell = onCopyCell
        self.onCopyRow = onCopyRow
        self.onCopyColumn = onCopyColumn
        self.onCopyColumnNames = onCopyColumnNames
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = DataTable()
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
            col.resizingMask = [.userResizingMask, .autoresizingMask]
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
        headerView.onSortColumnDirected = { [weak coordinator = context.coordinator] col, ascending in
            coordinator?.handleSort(at: col, ascending: ascending)
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
        if let dataTable = tableView as? DataTable {
            dataTable.onCopySelection = { [weak coordinator = context.coordinator] in
                coordinator?.copySelection()
            }
        }

        // Infinite scroll: observe clip-view bounds changes and trigger
        // onLoadMore near the bottom
        scrollView.contentView.postsBoundsChangedNotifications = true
        let scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator = context.coordinator] _ in
            coordinator?.dataTableDidScroll()
        }
        context.coordinator.scrollObserver = scrollObserver

        return scrollView
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let observer = coordinator.scrollObserver {
            NotificationCenter.default.removeObserver(observer)
            coordinator.scrollObserver = nil
        }
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let columnLayoutChanged = coordinator.columns != columns
        coordinator.columns = columns
        coordinator.rows = rows
        coordinator.startRow = startRow
        coordinator.hasMoreData = hasMoreData
        coordinator.hasPreviousData = hasPreviousData
        coordinator.onLoadPrevious = onLoadPrevious
        // Refresh EVERY callback: after a tab switch the same coordinator
        // serves the new tab — stale closures would drive the OLD tab's
        // manager (scrolling tab B paginating tab A)
        coordinator.onLoadMore = onLoadMore
        coordinator.onSort = onSort
        coordinator.onSortDirected = onSortDirected
        coordinator.onCopyCell = onCopyCell
        coordinator.onCopyRow = onCopyRow
        coordinator.onCopyColumn = onCopyColumn
        coordinator.onCopyColumnNames = onCopyColumnNames
        coordinator.hasPreviousData = hasPreviousData
        coordinator.dataVersion = dataVersion
        coordinator.isLoadingMore = isLoadingMore
        coordinator.fontSize = tableFontSize
        coordinator.sortColumn = sortColumn
        coordinator.sortAscending = sortAscending

        // Add/remove NSTableColumns so a different file loaded into the same
        // tab never shows stale columns with blank cells
        if let table = coordinator.dataTable, columnLayoutChanged {
            // Preserve user-set widths by column name across rebuilds
            // (file/tab switches reuse this coordinator)
            var widthsByName: [String: [CGFloat]] = [:]
            for col in table.tableColumns where col.identifier.rawValue != "col_rownum" {
                let clean = col.title
                    .replacingOccurrences(of: " ▲", with: "")
                    .replacingOccurrences(of: " ▼", with: "")
                widthsByName[clean, default: []].append(col.width)
                table.removeTableColumn(col)
            }
            for (index, name) in columns.enumerated() {
                let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
                col.title = name
                // duplicated names consume their widths positionally
                if let width = widthsByName[name]?.first {
                    widthsByName[name]?.removeFirst()
                    col.width = width
                } else {
                    col.width = 150
                }
                col.minWidth = 50
                col.maxWidth = 500
                col.resizingMask = [.userResizingMask, .autoresizingMask]
                table.addTableColumn(col)
            }
        }

        // Reload only when the data fingerprint changed
        if coordinator.reloadToken != coordinator.lastReloadToken {
            coordinator.lastReloadToken = coordinator.reloadToken

            let table = coordinator.dataTable
            let shift = pendingRowShift   // nil = semantic reset
            let oldSelection = table?.selectedRowIndexes ?? IndexSet()

            table?.reloadData()
            // New row rects + document height must exist before scrolling
            table?.layoutSubtreeIfNeeded()

            if let table {
                if let shift, shift != 0 {
                    // Pure index shift (prepend/trim): keep the selection AND
                    // anchor the viewport to the logical row it was showing
                    let newSel = IndexSet(oldSelection.map { $0 + shift }
                        .filter { $0 >= 0 && $0 < coordinator.rows.count })
                    if newSel.isEmpty { table.deselectAll(nil) }
                    else { table.selectRowIndexes(newSel, byExtendingSelection: false) }

                    let stride = table.numberOfRows > 0 ? table.rect(ofRow: 0).height : 0
                    if stride > 0 {
                        var origin = scrollView.contentView.bounds.origin
                        origin.y = max(0, origin.y + CGFloat(shift) * stride)
                        scrollView.contentView.scroll(to: origin)
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                } else {
                    // Jump / filter / sort / file switch: selection is
                    // meaningless in the new dataset
                    table.deselectAll(nil)
                }
            }
        }

        // Update sort indicators (skip col_rownum at index 0)
        if let table = coordinator.dataTable {
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
        var startRow: Int = 0
        var hasMoreData: Bool
        var hasPreviousData: Bool = false
        var isLoadingMore: Bool
        var fontSize: Double = 13.0
        var sortColumn: String?
        var sortAscending: Bool = true
        var onLoadMore: () -> Void
        var onLoadPrevious: () -> Void = {}
        var onSort: ((String) -> Void)?
        var onSortDirected: ((String, Bool) -> Void)? = nil
        var onCopyCell: ((Int, Int) -> Void)?
        var onCopyRow: ((Int) -> Void)?
        var onCopyColumn: ((Int) -> Void)?
        var onCopyColumnNames: (() -> Void)?

        weak var dataTable: NSTableView?
        weak var dataScrollView: NSScrollView?
        var scrollObserver: NSObjectProtocol?
        /// Cheap fingerprint of the last-rendered data; reloadData only fires
        /// when it changes, so unrelated SwiftUI updates (search keystrokes,
        /// focus changes) no longer wipe selection and scroll anchoring
        var lastReloadToken: Int = -1

        var reloadToken: Int {
            var hasher = Hasher()
            hasher.combine(columns)
            hasher.combine(dataVersion)
            hasher.combine(startRow)
            hasher.combine(fontSize)
            return hasher.finalize()
        }
        var dataVersion: UInt64 = 0

        init(
            columns: [String], rows: [[String]],
            hasMoreData: Bool, isLoadingMore: Bool,
            sortColumn: String?, sortAscending: Bool,
            onLoadMore: @escaping () -> Void,
            onLoadPrevious: @escaping () -> Void = {},
            onSortDirected: ((String, Bool) -> Void)? = nil,
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
            self.onLoadPrevious = onLoadPrevious
            self.onSortDirected = onSortDirected
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
                // Absolute row number (1-based) — stays aligned with the
                // global row range shown in the search bar after jumps
                tf?.stringValue = String(startRow + row + 1)
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
            } else {
                // Jagged row guard: a reused cell must not keep the previous
                // row's text/color
                tf?.stringValue = ""
                tf?.textColor = .labelColor
            }

            return cell
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            // Track the font size — a fixed 28pt clips at larger sizes
            max(fontSize + 15, UIConstants.tableRowHeight)
        }

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

        @objc func tableDoubleClick(_ sender: Any) {
            // Double-click copies the clicked cell — the only way to grab a
            // single value without cell-level selection
            guard let table = dataTable else { return }
            let row = table.clickedRow
            let col = table.clickedColumn
            guard row >= 0, col >= 0, row < rows.count else { return }
            if let di = dataColumnIndex(fromTableColumn: col), di < rows[row].count {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(rows[row][di], forType: .string)
            }
        }

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

        func handleSort(at tableColIndex: Int, ascending: Bool) {
            guard let di = dataColumnIndex(fromTableColumn: tableColIndex), di < columns.count else { return }
            if let directed = onSortDirected {
                directed(columns[di], ascending)
            } else {
                onSort?(columns[di])
            }
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

        /// Called on clip-view bounds changes (registered in makeNSView);
        /// triggers onLoadMore near the bottom, onLoadPrevious near the top
        func dataTableDidScroll() {
            guard let table = dataTable, !isLoadingMore else { return }
            let visible = table.rows(in: table.visibleRect)
            if hasMoreData, visible.upperBound - 1 >= rows.count - 10 {
                onLoadMore()
            } else if hasPreviousData, visible.lowerBound <= 10 {
                onLoadPrevious()
            }
        }
    }
}

/// NSTableView subclass so ⌘C flows through the responder chain: when the
/// TABLE is first responder it copies the table selection; when a text
/// field (search) has focus, the field's own copy wins — unlike a menu-item
/// key equivalent, which would always steal it.
final class DataTable: NSTableView {
    var onCopySelection: (() -> Void)?

    @objc(copy:) func copyFromResponderChain(_ sender: Any?) {
        onCopySelection?()
    }
}

// MARK: - Table Header View

class DataTableHeaderView: NSTableHeaderView {
    var onCopyColumn: ((Int) -> Void)?
    var onSortColumn: ((Int) -> Void)?
    var onSortColumnDirected: ((Int, Bool) -> Void)?

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
            // The resize grab zone straddles BOTH edges of the divider
            if abs(point.x - rect.maxX) < 5 || abs(point.x - rect.minX) < 5 {
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
            // Column titles carry the sort indicator ("▲/▼") when sorted —
            // strip it from the menu title
            let cleanTitle = tc.title
                .replacingOccurrences(of: " ▲", with: "")
                .replacingOccurrences(of: " ▼", with: "")
            let menu = NSMenu()

            let sortAsc = NSMenuItem(title: "table.sort_ascending".localizedWithFormat(cleanTitle),
                                     action: #selector(sortAscendingAction), keyEquivalent: "")
            sortAsc.target = self
            sortAsc.representedObject = column
            menu.addItem(sortAsc)

            let sortDesc = NSMenuItem(title: "table.sort_descending".localizedWithFormat(cleanTitle),
                                      action: #selector(sortDescendingAction), keyEquivalent: "")
            sortDesc.target = self
            sortDesc.representedObject = column
            menu.addItem(sortDesc)

            menu.addItem(.separator())

            let item = NSMenuItem(title: "table.copy_column".localizedWithFormat(cleanTitle), action: #selector(copyColumnAction), keyEquivalent: "")
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

    @objc func sortAscendingAction(_ sender: NSMenuItem) {
        guard let col = sender.representedObject as? Int else { return }
        if let directed = onSortColumnDirected {
            directed(col, true)
        } else {
            onSortColumn?(col)
        }
    }

    @objc func sortDescendingAction(_ sender: NSMenuItem) {
        guard let col = sender.representedObject as? Int else { return }
        if let directed = onSortColumnDirected {
            directed(col, false)
        } else {
            onSortColumn?(col)
            onSortColumn?(col)
        }
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
