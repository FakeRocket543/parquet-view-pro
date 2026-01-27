// Sidebar View
// Sidebar components for main interface
// SM-5: Main SwiftUI Interface

import SwiftUI

struct SidebarView: View {
    @ObservedObject var dbManager: DuckDBManager
    let recentFiles: [URL]
    let onOpenFile: () -> Void
    let onSelectRecentFile: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("Parquet View")
                    .font(.title2)
                    .bold()
            }
            .padding(.bottom, 8)

            Divider()

            // File Info
            if let info = dbManager.fileInfo {
                FileInfoSection(info: info, totalRows: dbManager.totalRowCount)

                // Sort indicator
                if let sortCol = dbManager.sortColumn {
                    HStack {
                        Image(systemName: dbManager.sortAscending ? "arrow.up" : "arrow.down")
                            .foregroundColor(.blue)
                        Text("Sorted by: \(sortCol)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            // Open File Button
            Button {
                onOpenFile()
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text("Open")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            // Recent Files
            if !recentFiles.isEmpty {
                Divider()
                RecentFilesSection(files: recentFiles, onSelect: onSelectRecentFile)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct FileInfoSection: View {
    let info: DuckDBManager.FileInfo
    let totalRows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current File")
                .font(.headline)
                .foregroundColor(.secondary)

            InfoRow(label: "Name", value: info.name)
            InfoRow(label: "Size", value: info.size)
            InfoRow(label: "Columns", value: "\(info.columnCount)")
            InfoRow(label: "Rows", value: "\(totalRows)")
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
        }
    }
}

struct RecentFilesSection: View {
    let files: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Files")
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(files.prefix(5), id: \.self) { url in
                Button {
                    onSelect(url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                            .font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        dbManager: DuckDBManager(),
        recentFiles: [],
        onOpenFile: {},
        onSelectRecentFile: { _ in }
    )
}
