// Data Table View
// High-performance table display with frozen row numbers
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
    private let rowNumberWidth: CGFloat = 60
    private let maxCopyRows = 10000

    @State private var showCopyAlert = false
    @State private var copyAlertMessage = ""
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                // Row number header (frozen left)
                Text("#")
                    .font(.system(.caption, design: .monospaced))
                    .bold()
                    .frame(width: rowNumberWidth, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 0.5)

                // Column headers (scrollable)
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                            Text(column)
                                .font(.system(.caption, design: .default))
                                .bold()
                                .frame(width: columnWidth, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .border(Color(NSColor.separatorColor), width: 0.5)
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
            }

            // Data rows
            HStack(spacing: 0) {
                // Row numbers (frozen left)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, _ in
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(width: rowNumberWidth, alignment: .center)
                            .padding(.vertical, 6)
                            .background(rowBackground(index: index))
                            .border(Color(NSColor.separatorColor), width: 0.5)
                            .frame(height: rowHeight)
                            .contextMenu {
                                Button {
                                    copyRow(at: index)
                                } label: {
                                    Label("Copy Row", systemImage: "doc.on.doc")
                                }
                            }
                    }

                    // Loading indicator row
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
                        .frame(maxWidth: .infinity)
                    }
                }

                // Data columns (scrollable)
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                                    Text(value)
                                        .font(.system(.caption, design: nil))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundColor(cellColor(value: value))
                                        .textSelection(.enabled)
                                        .frame(width: columnWidth, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(rowBackground(index: index))
                                        .border(Color(NSColor.separatorColor), width: 0.5)
                                        .help(value)
                                        .contextMenu {
                                            Button {
                                                copyCell(value)
                                            } label: {
                                                Label("Copy Cell", systemImage: "square.on.square")
                                            }

                                            Button {
                                                copyRow(at: index)
                                            } label: {
                                                Label("Copy Row", systemImage: "doc.on.doc")
                                            }

                                            if colIndex < columns.count, let columnName = columns[safe: colIndex] {
                                                Button {
                                                    copyColumn(at: colIndex)
                                                } label: {
                                                    Label("Copy Column (\(columnName))", systemImage: "list.bullet")
                                                }
                                            }
                                        }
                                }
                            }
                            .frame(height: rowHeight)
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
                    }
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

    /// Copy a single row
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
            ⚠️ \(rows.count) 行數據
            超過複製限制 \(maxCopyRows) 行

            💡 只複製前 \(maxCopyRows) 行
            """
            showCopyAlert = true
        }

        let limitedRows = Array(rows.prefix(maxCopyRows))
        let columnData = limitedRows.compactMap { row in
            return index < row.count ? row[index] : nil
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

// MARK: - Safe Array Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
