// Content View
// Main application interface
// SM-5: Main SwiftUI Interface

import SwiftUI

struct ContentView: View {
    @StateObject private var dbManager = DuckDBManager()
    @StateObject private var tabManager = TabManager()
    @State private var selectedFile: URL?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingJumpDialog = false
    @State private var jumpToRowNumber = ""
    @State private var jumpRowCount = "1000"
    @AppStorage("recentFiles") private var recentFilesData: Data = Data()
    @FocusState private var isSearchFocused: Bool
    
    // Zoom state
    @State private var currentZoom: CGFloat = 1.0
    @State private var steadyZoom: CGFloat = 1.0
    @State private var scrollOffset: CGSize = .zero
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 3.0
    
    private var recentFiles: [URL] {
        (try? JSONDecoder().decode([URL].self, from: recentFilesData)) ?? []
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarView
                .frame(minWidth: 220)
        } detail: {
            // Main content with optional tab bar
            VStack(spacing: 0) {
                // Tab bar (Pro only)
                if FeatureFlags.tabsEnabled && !tabManager.tabs.isEmpty {
                    TabBarView(tabManager: tabManager)
                    Divider()
                }
                
                // Content area
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(FeatureFlags.appName)
        .onAppear {
            setupNotifications()
            setupTabNotifications()
            enableFullScreen()
        }
        .onChange(of: tabManager.selectedTabID) { newValue in
            // When tab changes, load the corresponding file
            if let currentTab = tabManager.currentTab, let fileURL = currentTab.fileURL {
                selectedFile = fileURL
                Task {
                    await dbManager.loadParquet(url: fileURL)
                }
            } else {
                // Empty tab, show welcome screen
                selectedFile = nil
                dbManager.clearData()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                
                if !dbManager.rows.isEmpty {
                    Menu {
                        Button {
                            exportCSV()
                        } label: {
                            Label("Export as CSV", systemImage: "doc.text")
                        }
                        
                        Button {
                            exportParquet()
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
        .onOpenURL { url in
            loadFile(url: url)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingJumpDialog) {
            JumpToRowDialog(
                jumpToRowNumber: $jumpToRowNumber,
                jumpRowCount: $jumpRowCount,
                totalRows: dbManager.totalRowCount,
                onJump: {
                    if let rowNum = Int(jumpToRowNumber), let rowCount = Int(jumpRowCount) {
                        Task {
                            await dbManager.jumpToRow(rowNum, rowsToLoad: rowCount)
                        }
                        showingJumpDialog = false
                    }
                },
                onCancel: {
                    showingJumpDialog = false
                }
            )
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
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
            }
            
            // Open File Button
            Button {
                openFile()
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
                RecentFilesSection(files: recentFiles) { url in
                    loadFile(url: url)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        Group {
            if dbManager.isLoading {
                LoadingView()
            } else if let error = dbManager.errorMessage {
                ErrorView(message: error, retry: {
                    if let url = selectedFile {
                        loadFile(url: url)
                    }
                })
            } else if dbManager.rows.isEmpty {
                WelcomeView(onOpen: openFile)
            } else {
                VStack(spacing: 0) {
                    // Search and Navigation bar
                    HStack(spacing: 12) {
                        // Search
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(.plain)
                                .focused($isSearchFocused)
                                .onSubmit {
                                    Task {
                                        await dbManager.filterData(searchText: searchText)
                                    }
                                }
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    Task {
                                        await dbManager.filterData(searchText: "")
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Row info and jump button
                        if dbManager.totalRowCount > 1000 {
                            Divider()
                                .frame(height: 20)
                            
                            Text("Rows \(dbManager.currentStartRow + 1)-\(dbManager.currentStartRow + dbManager.displayedRowCount) of \(dbManager.totalRowCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize()
                            
                            Button {
                                showingJumpDialog = true
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .help("Jump to row...")
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Data table - NSTableView with native freeze pane
                    ParquetTableView(
                        columns: dbManager.columns,
                        rows: dbManager.rows,
                        onLoadMore: {},
                        hasMoreData: false,
                        isLoadingMore: false
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "parquet")!,
            .commaSeparatedText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Parquet or CSV file to view"
        
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }
    
    private func loadFile(url: URL) {
        selectedFile = url
        addToRecentFiles(url)
        
        // Handle tabs if Pro version
        if FeatureFlags.tabsEnabled {
            // Check if current tab is empty (Untitled)
            if let currentTab = tabManager.currentTab, currentTab.fileURL == nil {
                // Update the current empty tab instead of creating new one
                _ = tabManager.updateCurrentTab(fileURL: url)
            } else {
                // Create new tab
                if !tabManager.addTab(fileURL: url) {
                    // Show alert if tab limit reached
                    let alert = NSAlert()
                    alert.messageText = "Tab Limit Reached"
                    alert.informativeText = "Maximum \(tabManager.maxTabs) tabs allowed. Close some tabs or increase the limit in Settings."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
            }
        }
        
        Task {
            await dbManager.loadParquet(url: url)
        }
    }
    
    private func exportCSV() {
        exportData(format: .csv)
    }
    
    private func exportParquet() {
        exportData(format: .parquet)
    }
    
    private func exportData(format: DuckDBManager.ExportFormat) {
        let panel = NSSavePanel()
        
        switch format {
        case .csv:
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = selectedFile?.deletingPathExtension().lastPathComponent.appending(".csv") ?? "export.csv"
            panel.message = "Export data to CSV"
        case .parquet:
            panel.allowedContentTypes = [.init(filenameExtension: "parquet")!]
            panel.nameFieldStringValue = selectedFile?.deletingPathExtension().lastPathComponent.appending(".parquet") ?? "export.parquet"
            panel.message = "Export data to Parquet"
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    switch format {
                    case .csv:
                        try await dbManager.exportToCSV(url: url)
                    case .parquet:
                        try await dbManager.exportToParquet(url: url)
                    }
                    
                    // Show success message
                    let alert = NSAlert()
                    alert.messageText = "Export Successful"
                    alert.informativeText = "Data exported to \(url.lastPathComponent)"
                    alert.alertStyle = .informational
                    alert.runModal()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
    
    private func addToRecentFiles(_ url: URL) {
        var recent = recentFiles
        recent.removeAll { $0 == url }
        recent.insert(url, at: 0)
        if recent.count > 10 {
            recent = Array(recent.prefix(10))
        }
        if let data = try? JSONEncoder().encode(recent) {
            recentFilesData = data
        }
    }
    
    // MARK: - Notification Handlers
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openFile,
            object: nil,
            queue: .main
        ) { _ in
            openFile()
        }
        
        NotificationCenter.default.addObserver(
            forName: .exportCSV,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                exportCSV()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .exportParquet,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                exportParquet()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .focusSearch,
            object: nil,
            queue: .main
        ) { _ in
            if !dbManager.rows.isEmpty {
                isSearchFocused = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomIn,
            object: nil,
            queue: .main
        ) { _ in
            zoomIn()
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomOut,
            object: nil,
            queue: .main
        ) { _ in
            zoomOut()
        }
        
        NotificationCenter.default.addObserver(
            forName: .zoomReset,
            object: nil,
            queue: .main
        ) { _ in
            zoomReset()
        }
    }
    
    private func setupTabNotifications() {
        guard FeatureFlags.tabsEnabled else { return }
        
        NotificationCenter.default.addObserver(
            forName: .openFileFromTab,
            object: nil,
            queue: .main
        ) { _ in
            openFile()
        }
        
        NotificationCenter.default.addObserver(
            forName: .createEmptyTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                guard let tabManager = tabManager else { return }
                
                // Create empty tab in tab manager
                if tabManager.addEmptyTab() {
                    // Clear current file to show welcome screen
                    selectedFile = nil
                    dbManager.clearData()
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .closeCurrentTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                guard let tabManager = tabManager else { return }
                if let selectedID = tabManager.selectedTabID {
                    tabManager.closeTab(id: selectedID)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .closeOtherTabs,
            object: nil,
            queue: .main
        ) { [weak tabManager] notification in
            Task { @MainActor in
                guard let tabManager = tabManager else { return }
                if let tabID = notification.userInfo?["tabID"] as? UUID {
                    tabManager.closeOtherTabs(except: tabID)
                } else if let selectedID = tabManager.selectedTabID {
                    tabManager.closeOtherTabs(except: selectedID)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .closeAllTabs,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.closeAllTabs()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .nextTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.selectNextTab()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .previousTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.selectPreviousTab()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .selectTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] notification in
            Task { @MainActor in
                guard let tabManager = tabManager,
                      let index = notification.userInfo?["index"] as? Int,
                      index < tabManager.tabs.count else { return }
                tabManager.selectTab(id: tabManager.tabs[index].id)
            }
        }
    }
    
    // MARK: - Zoom Functions
    
    private func zoomIn() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentZoom = min(currentZoom * 1.2, maxZoom)
            steadyZoom = currentZoom
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentZoom = max(currentZoom / 1.2, minZoom)
            steadyZoom = currentZoom
        }
    }
    
    private func zoomReset() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentZoom = 1.0
            steadyZoom = 1.0
        }
    }
    
    private func enableFullScreen() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.collectionBehavior = [.fullScreenPrimary]
                window.titlebarAppearsTransparent = false
            }
        }
    }
}

// MARK: - Dynamic Font Scale Environment Key

private struct DynamicFontScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var dynamicFontScale: Double {
        get { self[DynamicFontScaleKey.self] }
        set { self[DynamicFontScaleKey.self] = newValue }
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

struct SearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSearch)
            
            if !text.isEmpty {
                Button {
                    text = ""
                    onSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct WelcomeView: View {
    let onOpen: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Welcome to Parquet View")
                        .font(.title)
                        .bold()
                    
                    Text("Open a Parquet or CSV file to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Button {
                        onOpen()
                    } label: {
                        Label("Open File", systemImage: "folder")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("or drag and drop a file here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
