// Notification Handlers
// Manages application-level notification observers
// SM-5: Main SwiftUI Interface

import SwiftUI

/// Application notification handlers component
/// responsible for setting up and managing application-level notifications
struct NotificationHandlers {
    let dbManager: DuckDBManager
    let openFile: () -> Void
    let exportCSV: () -> Void
    let exportParquet: () -> Void
    let increaseFontSize: () -> Void
    let decreaseFontSize: () -> Void
    let resetFontSize: () -> Void
    @FocusState.Binding var isSearchFocused: Bool

    /// Setup all application-level notification observers
    func setupNotifications() {
        // Open file notification
        NotificationCenter.default.addObserver(
            forName: .openFile,
            object: nil,
            queue: .main
        ) { _ in
            openFile()
        }

        // Export CSV notification
        NotificationCenter.default.addObserver(
            forName: .exportCSV,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                exportCSV()
            }
        }

        // Export Parquet notification
        NotificationCenter.default.addObserver(
            forName: .exportParquet,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                exportParquet()
            }
        }

        // Focus search notification
        NotificationCenter.default.addObserver(
            forName: .focusSearch,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                isSearchFocused = true
            }
        }

        // Increase font size notification
        NotificationCenter.default.addObserver(
            forName: .increaseFontSize,
            object: nil,
            queue: .main
        ) { _ in
            increaseFontSize()
        }

        // Decrease font size notification
        NotificationCenter.default.addObserver(
            forName: .decreaseFontSize,
            object: nil,
            queue: .main
        ) { _ in
            decreaseFontSize()
        }

        // Reset font size notification
        NotificationCenter.default.addObserver(
            forName: .resetFontSize,
            object: nil,
            queue: .main
        ) { _ in
            resetFontSize()
        }
    }
}
