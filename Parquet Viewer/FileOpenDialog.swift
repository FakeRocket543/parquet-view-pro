// File Open Dialog
// Handles file selection with support for multiple files (Pro feature)
// SM-5: File dialog component

import SwiftUI
import UniformTypeIdentifiers

/// File open dialog component with callback for selected files
struct FileOpenDialog {

    /// Result of file selection
    enum SelectionResult {
        case single(URL)
        case multiple([URL])
        case cancelled
    }

    /// Presents the file open dialog and calls the completion handler with selected files
    /// - Parameter completion: Callback with selection result
    static func present(completion: @escaping (SelectionResult) -> Void) {
        let panel = NSOpenPanel()

        // Safely create UTType for parquet files
        let parquetContentType = UTType(filenameExtension: "parquet")
        var allowedTypes: [UTType] = []

        if let parquetType = parquetContentType {
            allowedTypes.append(parquetType)
        }
        allowedTypes.append(.commaSeparatedText)

        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = FeatureFlags.tabsEnabled  // Pro feature: multiple selection
        panel.canChooseDirectories = false
        panel.message = FeatureFlags.tabsEnabled
            ? "Select one or more Parquet/CSV files to view"
            : "Select a Parquet or CSV file to view"

        panel.begin { response in
            guard response == .OK else {
                completion(.cancelled)
                return
            }

            let urls = panel.urls
            guard !urls.isEmpty else {
                completion(.cancelled)
                return
            }

            // Return single or multiple based on count
            if urls.count == 1 {
                completion(.single(urls[0]))
            } else {
                completion(.multiple(urls))
            }
        }
    }
}
