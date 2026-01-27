// File Action Buttons
// Toolbar button component for file operations
// SM-5: Main SwiftUI Interface

import SwiftUI

struct FileActionButtons: View {
    // State bindings
    @Binding var showingStatsPanel: Bool
    @Binding var showingSettings: Bool

    // Data state
    let hasData: Bool
    let hasColumnStats: Bool

    // Action callbacks
    let onShowStats: () -> Void
    let onExportCSV: () -> Void
    let onExportParquet: () -> Void

    var body: some View {
        Group {
            // Stats button (calculate and show column statistics)
            if hasData {
                Button {
                    onShowStats()
                } label: {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .help("View column statistics")
            }

            if hasData {
                Menu {
                    Button {
                        onExportCSV()
                    } label: {
                        Label("Export as CSV", systemImage: "doc.text")
                    }

                    Button {
                        onExportParquet()
                    } label: {
                        Label("Export as Parquet", systemImage: "doc.badge.gearshape")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FileActionButtons(
        showingStatsPanel: .constant(false),
        showingSettings: .constant(false),
        hasData: true,
        hasColumnStats: false,
        onShowStats: {},
        onExportCSV: {},
        onExportParquet: {}
    )
}
