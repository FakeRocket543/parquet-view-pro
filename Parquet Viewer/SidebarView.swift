// Sidebar View
// Sidebar components for main interface
// SM-5: Main SwiftUI Interface
// (The sidebar itself is composed inline in ContentView; the reusable
// sections below are the live pieces.)

import SwiftUI

// MARK: - Supporting Views

struct FileInfoSection: View {
    let info: DuckDBManager.FileInfo
    let totalRows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("fileinfo.title".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            InfoRow(label: "fileinfo.name".localized, value: info.name)
            InfoRow(label: "fileinfo.size".localized, value: info.size)
            InfoRow(label: "fileinfo.columns".localized, value: "\(info.columnCount)")
            InfoRow(label: "fileinfo.rows".localized, value: "\(totalRows)")
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
            Text("recent.title".localized)
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

#Preview {
    FileInfoSection(
        info: DuckDBManager.FileInfo(name: "data.parquet", path: "/tmp/data.parquet", size: "1.2 MB", columnCount: 5),
        totalRows: 12345
    )
}
