// Data Table View
// High-performance table display with virtual scrolling
// SM-6: Data Table View Component

import SwiftUI

struct DataTableView: View {
    let columns: [String]
    let rows: [[String]]
    let isLoadingMore: Bool
    let hasMoreData: Bool
    let onLoadMore: () -> Void
    
    private let columnWidth: CGFloat = 180
    private let rowHeight: CGFloat = 28
    private let maxCopyRows = 10000 // ???? 10000 ?
    
    @State private var showCopyAlert = false
    @State private var copyAlertMessage = ""
    @State private var selectedRow: Int?
    @State private var selectedColumn: Int?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Data rows
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        rowView(row: row, index: index)
                            .onAppear {
                                // Load more when approaching the end
                                if index == rows.count - 10 && hasMoreData && !isLoadingMore {
                                    onLoadMore()
                                }
                            }
                    }
                    
                    // Loading indicator
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Text("Loading more...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(height: rowHeight)
                    }
                } header: {
                    // Column headers
                    headerView
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Copy Limit", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(copyAlertMessage)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 0) {
            // Row number column
            Text("#")
                .font(.system(.caption, design: .monospaced))
                .bold()
                .frame(width: 60, alignment: .center)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .border(Color(NSColor.separatorColor), width: 0.5)
            
            // Data columns with copy column context menu
            ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                Text(column)
                    .font(.system(.caption, design: .default))
                    .bold()
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 0.5)
                    .help(column) // Tooltip
                    .contextMenu {
                        Button {
                            copyColumn(at: colIndex)
                        } label: {
                            Label("Copy Column (\(column))", systemImage: "list.bullet")
                        }
                    }
            }
        }
    }
    
    // MARK: - Row View
    
    private func rowView(row: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            // Row number with copy row context menu
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .center)
                .padding(.vertical, 6)
                .background(rowBackground(index: index))
                .border(Color(NSColor.separatorColor), width: 0.5)
                .contextMenu {
                    Button {
                        copyRow(at: index)
                    } label: {
                        Label("Copy This Row", systemImage: "doc.on.doc")
                    }
                }
            
            // Data cells
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                cellView(value: value, columnIndex: colIndex, rowIndex: index)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(rowBackground(index: index))
                    .border(Color(NSColor.separatorColor), width: 0.5)
            }
        }
        .frame(height: rowHeight)
    }
    
    // MARK: - Cell View
    
    private func cellView(value: String, columnIndex: Int, rowIndex: Int) -> some View {
        Text(value)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundColor(cellColor(value: value))
            .textSelection(.enabled) // Enable text selection
            .help(value) // Show full value on hover
            .contextMenu {
                Button {
                    copyCell(value)
                } label: {
                    Label("Copy Cell", systemImage: "square.on.square")
                }
                
                Button {
                    copyRow(at: rowIndex)
                } label: {
                    Label("Copy Row", systemImage: "doc.on.doc")
                }
                
                Button {
                    copyColumn(at: columnIndex)
                } label: {
                    Label("Copy Column (\(columns[columnIndex]))", systemImage: "list.bullet")
                }
            }
    }
    
    // MARK: - Styling Helpers
    
    private func rowBackground(index: Int) -> Color {
        index % 2 == 0 ? Color(NSColor.textBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.3)
    }
    
    private func cellColor(value: String) -> Color {
        if value == "NULL" {
            return .secondary
        } else if value == "true" || value == "false" {
            return .blue
        } else if Double(value) != nil {
            return .purple
        } else {
            return .primary
        }
    }
    
    // MARK: - Copy Functions
    
    /// Copy a single cell
    private func copyCell(_ value: String) {
        copyToClipboard(value)
    }
    
    /// Copy a single row (with limits)
    private func copyRow(at index: Int) {
        guard index < rows.count else { return }
        let rowData = rows[index]
        let text = rowData.joined(separator: "\t")
        copyToClipboard(text)
    }
    
    /// Copy a single column (with limits)
    private func copyColumn(at index: Int) {
        guard index < columns.count else { return }
        
        // Check limit
        if rows.count > maxCopyRows {
            copyAlertMessage = """
            ?? \(rows.count) ????
            ?????????????????? \(maxCopyRows) ??
            
            ?? ???????????????????
            """
            showCopyAlert = true
        }
        
        let limitedRows = Array(rows.prefix(maxCopyRows))
        let columnData = limitedRows.compactMap { row in
            index < row.count ? row[index] : nil
        }
        let text = columnData.joined(separator: "\n")
        copyToClipboard(text)
    }
    
    /// Copy text to clipboard
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    DataTableView(
        columns: ["ID", "Name", "Age", "Score"],
        rows: [
            ["1", "Alice", "25", "95.5"],
            ["2", "Bob", "30", "87.3"],
            ["3", "Charlie", "NULL", "92.1"]
        ],
        isLoadingMore: false,
        hasMoreData: false,
        onLoadMore: {}
    )
}
