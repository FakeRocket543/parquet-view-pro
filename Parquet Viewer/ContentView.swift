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
    @AppStorage("tableFontSize") private var tableFontSize: Double = 13.0
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
        DetailView(
            dbManager: dbManager,
            selectedFile: $selectedFile,
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            showingJumpDialog: $showingJumpDialog,
            jumpToRowNumber: $jumpToRowNumber,
            jumpRowCount: $jumpRowCount,
            openFile: openFile
        )
    }
    
    // MARK: - Actions
    
    private func openFile() {
        FileOpenDialog.present { result in
            switch result {
            case .single(let url):
                loadFile(url: url)
            case .multiple(let urls):
                if FeatureFlags.tabsEnabled {
                    openMultipleFiles(urls: urls)
                } else {
                    // Free version: only open first file
                    if let url = urls.first {
                        loadFile(url: url)
                    }
                }
            case .cancelled:
                break
            }
        }
    }
    
    private func openMultipleFiles(urls: [URL]) {
        guard FeatureFlags.tabsEnabled else { return }
        
        var successCount = 0
        var failedFiles: [String] = []
        
        for url in urls {
            // 檢查是否達到分頁上限
            if tabManager.tabs.count >= tabManager.maxTabs {
                failedFiles.append(contentsOf: urls.dropFirst(successCount).map { $0.lastPathComponent })
                break
            }
            
            // 載入檔案到新分頁
            addToRecentFiles(url)
            
            // 檢查當前分頁是否為空
            if successCount == 0, let currentTab = tabManager.currentTab, currentTab.fileURL == nil {
                // 更新當前空分頁
                selectedFile = url
                _ = tabManager.updateCurrentTab(fileURL: url)
                Task {
                    await dbManager.loadParquet(url: url)
                }
            } else {
                // 創建新分頁
                if tabManager.addTab(fileURL: url) {
                    // 如果是最後一個檔案，切換到該分頁
                    if url == urls.last {
                        selectedFile = url
                        Task {
                            await dbManager.loadParquet(url: url)
                        }
                    }
                } else {
                    failedFiles.append(url.lastPathComponent)
                    continue
                }
            }
            
            successCount += 1
        }
        
        // 顯示結果訊息
        if !failedFiles.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Some Files Not Opened"
            alert.informativeText = """
                Successfully opened: \(successCount) file(s)
                Failed to open: \(failedFiles.count) file(s)
                
                Reason: Tab limit (\(tabManager.maxTabs)) reached.
                
                Failed files:
                \(failedFiles.joined(separator: "\n"))
                
                Tip: Increase tab limit in Settings or close some tabs.
                """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else if successCount > 1 {
            // 成功開啟多個檔案，顯示提示
            let alert = NSAlert()
            alert.messageText = "Files Opened Successfully"
            alert.informativeText = "Successfully opened \(successCount) files in separate tabs."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            // 自動關閉通知（2秒後）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NSApp.abortModal()
            }
            
            alert.runModal()
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
        let handlers = NotificationHandlers(
            dbManager: dbManager,
            openFile: openFile,
            exportCSV: exportCSV,
            exportParquet: exportParquet,
            increaseFontSize: increaseFontSize,
            decreaseFontSize: decreaseFontSize,
            resetFontSize: resetFontSize,
            isSearchFocused: $isSearchFocused
        )
        handlers.setupNotifications()
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
    
    private func increaseFontSize() {
        tableFontSize = min(tableFontSize + 1, 20)
    }
    
    private func decreaseFontSize() {
        tableFontSize = max(tableFontSize - 1, 9)
    }
    
    private func resetFontSize() {
        tableFontSize = 13.0
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

// MARK: - Preview

#Preview {
    ContentView()
}
