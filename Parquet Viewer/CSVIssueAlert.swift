// CSV Issue Alert Dialog
// Shows user options when CSV file has integrity issues

import SwiftUI

/// Alert view for CSV integrity issues
struct CSVIssueAlert: View {
    let checkResult: CSVIntegrityCheckResult
    let fileURL: URL
    let onDismiss: () -> Void
    let onAction: (CSVRepairAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("CSV 檔案問題")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Issue description
            VStack(alignment: .leading, spacing: 12) {
                if let description = checkResult.issueDescription {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("檢測到問題")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // File info
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()

            Divider()

            // Actions
            VStack(spacing: 8) {
                ForEach(checkResult.suggestedActions) { action in
                    Button(action: { onAction(action) }) {
                        HStack {
                            Image(systemName: action.icon)
                                .frame(width: 24)
                            Text(action.description)
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Cancel button
                Button(action: onDismiss) {
                    Text("取消")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

/// Preview provider
#Preview {
    CSVIssueAlert(
        checkResult: CSVIntegrityCheckResult(
            isValid: false,
            issueType: .truncatedLastRow,
            issueDescription: "最後一行被截斷（預期 5 欄，實際 3 欄）",
            suggestedActions: [
                .skipLastRow,
                .ignoreAndLoad,
                .openWithExternalTool
            ],
            lastValidRowIndex: 1531
        ),
        fileURL: URL(fileURLWithPath: "/Users/test/demo/gwen.csv"),
        onDismiss: {},
        onAction: { _ in }
    )
}
