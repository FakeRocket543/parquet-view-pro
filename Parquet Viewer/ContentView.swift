// Content View
// Main application interface
// SM-5: Main SwiftUI Interface

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
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
    
    // Combine cancellables for notification subscriptions
    @State private var cancellables = Set<AnyCancellable>()

    // Drives the native View ▸ Toggle Sidebar command
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Current tab's dbManager (computed from tabManager)
    private var dbManager: DuckDBManager? {
        tabManager.currentDBManager
    }

    private var recentFiles: [URL] {
        (try? JSONDecoder().decode([URL].self, from: recentFilesData)) ?? []
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            sidebarView
                .frame(minWidth: 220)
        } detail: {
            // Main content with optional tab bar
            VStack(spacing: 0) {
                // Tab bar (Pro only)
                if FeatureFlags.tabsEnabled && !tabManager.tabs.isEmpty {
                    TabBarView(
                        tabManager: tabManager,
                        onCreateEmptyTab: {
                            if tabManager.addEmptyTab() {
                                selectedFile = nil
                            }
                        },
                        onCloseOtherTabs: { tabID in
                            tabManager.closeOtherTabs(except: tabID)
                        },
                        onCloseAllTabs: {
                            tabManager.closeAllTabs()
                        }
                    )
                    Divider()
                }
                
                // Content area
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(FeatureFlags.appName)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, FileType.isSupported(url) else { return }
                    DispatchQueue.main.async { self.loadFile(url: url) }
                }
            }
            return true
        }
        .onAppear {
            // onAppear can fire more than once (fullscreen transitions,
            // sidebar restore) — clear old subscriptions or every Cmd
            // shortcut would fire twice
            cancellables.removeAll()
            setupNotificationsWithCombine()
            setupTabNotificationsWithCombine()
            enableFullScreen()
        }
        .onChange(of: tabManager.selectedTabID) { _ in
            // Sync the search field with the incoming tab's actual filter
            // state, so a filtered tab never shows an empty search box
            searchText = tabManager.currentDBManager?.activeFilterText ?? ""
            // Tab switched - data is already in the tab's dbManager, just update selectedFile
            if let currentTab = tabManager.currentTab, let fileURL = currentTab.fileURL {
                selectedFile = fileURL
            } else {
                selectedFile = nil
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                
                if let manager = dbManager, !manager.rows.isEmpty {
                    Menu {
                        Button {
                            exportCSV()
                        } label: {
                            Label("export.as_csv".localized, systemImage: "doc.text")
                        }
                        
                        Button {
                            exportParquet()
                        } label: {
                            Label("export.as_parquet".localized, systemImage: "doc.badge.gearshape")
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
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Pick up settings that the manager caches at creation time
            tabManager.reloadSettings()
        }) {
            SettingsView()
        }
        .sheet(isPresented: $showingJumpDialog) {
            JumpToRowDialog(
                jumpToRowNumber: $jumpToRowNumber,
                jumpRowCount: $jumpRowCount,
                totalRows: dbManager?.totalRowCount ?? 0,
                onJump: {
                    guard let manager = dbManager else { return }
                    // Clamp authoritatively here — the dialog's disabled
                    // state is advisory only
                    let rowNum = min(max(Int(jumpToRowNumber) ?? 1, 1),
                                     max(manager.totalRowCount, 1))
                    let rowCount = min(max(Int(jumpRowCount) ?? DataConstants.defaultMaxRows, 1),
                                       DataConstants.maxMaxRows)
                    Task {
                        await manager.jumpToRow(rowNum, rowsToLoad: rowCount)
                    }
                    showingJumpDialog = false
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
                Text("app.name".localized)
                    .font(.title2)
                    .bold()
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // File Info
            if let manager = dbManager, let info = manager.fileInfo {
                FileInfoSection(info: info, totalRows: manager.totalRowCount)

                // Active sort indicator
                if let sortCol = manager.sortColumn {
                    HStack {
                        Image(systemName: manager.sortAscending ? "arrow.up" : "arrow.down")
                            .foregroundColor(.blue)
                        Text("fileinfo.sorted_by".localizedWithFormat(sortCol))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            // Open File Button
            Button {
                openFile()
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text("button.open".localized)
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
    
    @ViewBuilder
    private var detailView: some View {
        if let manager = dbManager {
            DetailView(
                dbManager: manager,
                selectedFile: $selectedFile,
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                showingJumpDialog: $showingJumpDialog,
                jumpToRowNumber: $jumpToRowNumber,
                jumpRowCount: $jumpRowCount,
                openFile: openFile
            )
        } else {
            WelcomeView(onOpen: openFile)
        }
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
        var alreadyOpenCount = 0
        var failedFiles: [String] = []
        var firstOpenedTabFile: URL?

        for url in urls {
            // 檢查是否達到分頁上限
            if tabManager.tabs.count >= tabManager.maxTabs {
                failedFiles.append(contentsOf: urls.dropFirst(successCount + alreadyOpenCount).map { $0.lastPathComponent })
                break
            }

            // 已開啟的檔案：只選取既有分頁，不重複載入
            if let existing = tabManager.tabs.first(where: { $0.fileURL == url }) {
                if firstOpenedTabFile == nil { firstOpenedTabFile = url }
                tabManager.selectTab(id: existing.id)
                alreadyOpenCount += 1
                continue
            }

            addToRecentFiles(url)

            // 檢查當前分頁是否為空
            if successCount == 0, let currentTab = tabManager.currentTab, currentTab.fileURL == nil {
                // 更新當前空分頁
                _ = tabManager.updateCurrentTab(fileURL: url)
                Task {
                    await currentTab.dbManager.loadParquet(url: url)
                }
            } else {
                // 創建新分頁
                if tabManager.addTab(fileURL: url),
                   let newTab = tabManager.tabs.last {
                    Task {
                        await newTab.dbManager.loadParquet(url: url)
                    }
                } else {
                    failedFiles.append(url.lastPathComponent)
                    continue
                }
            }
            if firstOpenedTabFile == nil { firstOpenedTabFile = url }
            successCount += 1
        }

        // 批次開完後停在第一個開啟的檔案，而不是 flicker 到最後一個
        if let first = firstOpenedTabFile,
           let tab = tabManager.tabs.first(where: { $0.fileURL == first }) {
            tabManager.selectTab(id: tab.id)
            selectedFile = first
        }

        // 只在有失敗時提示；全數成功時新分頁本身就是回饋
        //（原本的自動關閉 modal 會阻斷互動且違反 HIG）
        if !failedFiles.isEmpty {
            let alert = NSAlert()
            alert.messageText = "batch.partial.title".localized
            alert.informativeText = "batch.partial.detail".localizedWithFormat(
                successCount + alreadyOpenCount, failedFiles.count, tabManager.maxTabs,
                failedFiles.joined(separator: "\n")
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: "alert.ok".localized)
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
                Task {
                    await currentTab.dbManager.loadParquet(url: url)
                }
            } else {
                // Re-opening an already-open file: select its existing tab —
                // do NOT load into tabs.last (that would put this file's
                // data into an unrelated tab while keeping its old title)
                if let existing = tabManager.tabs.first(where: { $0.fileURL == url }) {
                    tabManager.selectTab(id: existing.id)
                    selectedFile = url
                    return
                }
                // Create new tab
                if !tabManager.addTab(fileURL: url) {
                    // Show alert if tab limit reached
                    let alert = NSAlert()
                    alert.messageText = "tabs.limit.title".localized
                    alert.informativeText = "tabs.limit.detail".localizedWithFormat(tabManager.maxTabs)
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "alert.ok".localized)
                    alert.runModal()
                    return
                }
                // Load data into the new tab's dbManager
                if let newTab = tabManager.tabs.last {
                    Task {
                        await newTab.dbManager.loadParquet(url: url)
                    }
                }
            }
        } else {
            // No tabs - use current dbManager
            if let manager = dbManager {
                Task {
                    await manager.loadParquet(url: url)
                }
            }
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
            if let parquetType = UTType(filenameExtension: "parquet") {
                panel.allowedContentTypes = [parquetType]
            }
            panel.nameFieldStringValue = selectedFile?.deletingPathExtension().lastPathComponent.appending(".parquet") ?? "export.parquet"
            panel.message = "Export data to Parquet"
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let manager = dbManager else { return }
            Task {
                do {
                    switch format {
                    case .csv:
                        try await manager.exportToCSV(url: url)
                    case .parquet:
                        try await manager.exportToParquet(url: url)
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
    
    // MARK: - Notification Handlers (Combine)

    private func setupNotificationsWithCombine() {
        // Open file notification
        NotificationCenter.default.publisher(for: .openFile)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                openFile()
            }
            .store(in: &cancellables)

        // Export CSV notification
        NotificationCenter.default.publisher(for: .exportCSV)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                if let dbManager = tabManager?.currentDBManager, !dbManager.rows.isEmpty {
                    exportCSV()
                }
            }
            .store(in: &cancellables)

        // Export Parquet notification
        NotificationCenter.default.publisher(for: .exportParquet)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                if let dbManager = tabManager?.currentDBManager, !dbManager.rows.isEmpty {
                    exportParquet()
                }
            }
            .store(in: &cancellables)

        // Settings (⌘,)
        NotificationCenter.default.publisher(for: .showSettings)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                showingSettings = true
            }
            .store(in: &cancellables)

        // Focus search notification
        NotificationCenter.default.publisher(for: .focusSearch)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                // hasLoadedFile, not rows.isEmpty: a search that returned
                // zero rows must not kill ⌘F exactly when it's needed most
                if let dbManager = tabManager?.currentDBManager, dbManager.hasLoadedFile {
                    isSearchFocused = true
                }
            }
            .store(in: &cancellables)

        // Increase font size notification
        NotificationCenter.default.publisher(for: .increaseFontSize)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                increaseFontSize()
            }
            .store(in: &cancellables)

        // Decrease font size notification
        NotificationCenter.default.publisher(for: .decreaseFontSize)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                decreaseFontSize()
            }
            .store(in: &cancellables)

        // Reset font size notification
        NotificationCenter.default.publisher(for: .resetFontSize)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                resetFontSize()
            }
            .store(in: &cancellables)
    }
    
    private func setupTabNotificationsWithCombine() {
        guard FeatureFlags.tabsEnabled else { return }
        
        // Open file from tab
        NotificationCenter.default.publisher(for: .openFileFromTab)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                openFile()
            }
            .store(in: &cancellables)
        
        // Create empty tab
        NotificationCenter.default.publisher(for: .createEmptyTab)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                guard let tabManager = tabManager else { return }
                if tabManager.addEmptyTab() {
                    selectedFile = nil
                }
            }
            .store(in: &cancellables)
        
        // Close current tab
        NotificationCenter.default.publisher(for: .closeCurrentTab)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                guard let tabManager = tabManager else { return }
                if let selectedID = tabManager.selectedTabID {
                    tabManager.closeTab(id: selectedID)
                }
            }
            .store(in: &cancellables)
        
        // Close other tabs
        NotificationCenter.default.publisher(for: .closeOtherTabs)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] notification in
                guard let tabManager = tabManager else { return }
                if let tabID = notification.userInfo?["tabID"] as? UUID {
                    tabManager.closeOtherTabs(except: tabID)
                } else if let selectedID = tabManager.selectedTabID {
                    tabManager.closeOtherTabs(except: selectedID)
                }
            }
            .store(in: &cancellables)
        
        // Close all tabs
        NotificationCenter.default.publisher(for: .closeAllTabs)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                tabManager?.closeAllTabs()
            }
            .store(in: &cancellables)
        
        // Next tab
        NotificationCenter.default.publisher(for: .nextTab)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                tabManager?.selectNextTab()
            }
            .store(in: &cancellables)
        
        // Previous tab
        NotificationCenter.default.publisher(for: .previousTab)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] _ in
                tabManager?.selectPreviousTab()
            }
            .store(in: &cancellables)
        
        // Select tab by index
        NotificationCenter.default.publisher(for: .selectTab)
            .receive(on: DispatchQueue.main)
            .sink { [weak tabManager] notification in
                guard let tabManager = tabManager,
                      let index = notification.userInfo?["index"] as? Int,
                      index < tabManager.tabs.count else { return }
                tabManager.selectTab(id: tabManager.tabs[index].id)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Font Size Functions
    
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

// MARK: - Preview

#Preview {
    ContentView()
}
