# Parquet View Pro - ??????

## ????

**Parquet View Pro** ??????? Parquet/CSV ???????? macOS ?????

### ????
- ? ????????????????
- ? Freeze Pane ?????
- ? CSV ? Parquet ????
- ? ??????????
- ? ?????????
- ? ?????
- ? ??????/?/???
- ? ?????
- ? ??????????
- ? Recent Files ????
- ? ??? macOS ??????????Dock?

---

## ???

### ????
- **??**?Swift 6.0
- **UI ??**?SwiftUI + AppKit
- **?????**?DuckDB 1.1.3
- **????**?Swift Package Manager
- **????**?macOS 13.0 (Ventura)

### ????
```swift
dependencies: [
    .package(url: "https://github.com/duckdb/duckdb-swift", from: "1.1.3")
]
```

---

## ????

```
ParquetViewerSwift/
??? Parquet Viewer/
?   ??? ParquetViewApp.swift           # App ???Window & Menu ??
?   ??? AppDelegate.swift              # macOS ??????
?   ??? ContentView.swift              # ??????
?   ??? DataTableView.swift            # ?????? Freeze Pane?
?   ??? DuckDBManager.swift            # DuckDB ???
?   ??? TabManager.swift               # ?????
?   ??? SettingsView.swift             # ????
?   ??? JumpToRowDialog.swift          # ??????
?   ??? BuildConfig.swift              # ??????
?   ??? Localizable.swift              # ?????
?   ??? SyncedScrollView.swift         # ??????????
?   ??? ZoomableScrollView.swift       # ????????
??? docs/
?   ??? FREEZE_PANE_IMPLEMENTATION.md  # Freeze Pane ????
?   ??? PROJECT_ARCHITECTURE.md        # ???
?   ??? PERFORMANCE_FIX_LAZYVSTACK.md  # ??????
?   ??? CSV_SUPPORT_FIX.md            # CSV ????
??? build_pro.sh                       # ???????
??? Package.swift                      # SPM ??
??? README.md                          # ????
```

---

## ??????

### 1. ParquetViewApp.swift - ??????

**???**
- ?? App ????
- ?? Window ???????????
- ?? macOS ????
- ?????

**?????**
```swift
@main
struct ParquetViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") { ... }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Close Tab") { ... }
                    .keyboardShortcut("w", modifiers: .command)
            }
            
            if FeatureFlags.tabsEnabled {
                CommandMenu("Tab") {
                    Button("New Tab") { ... }
                        .keyboardShortcut("t", modifiers: .command)
                    Button("Select Tab 1") { ... }
                        .keyboardShortcut("1", modifiers: .command)
                    // ... Cmd+1 ? Cmd+0
                }
            }
            
            CommandMenu("View") {
                Button("Zoom In") { ... }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { ... }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { ... }
                    .keyboardShortcut("0", modifiers: [.command, .option])
            }
        }
    }
}
```

**AppDelegate ???**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Cmd+Q ?????
        let alert = NSAlert()
        alert.messageText = "Quit?"
        // ...
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // ?? Cmd+W ?????????
    }
}
```

---

### 2. ContentView.swift - ??????

**???**
- ?????????selectedFile, recent files?
- ???????Sidebar, DataTableView, TabBar?
- ???????Tab ??
- ???????NotificationCenter?

**?????**
```swift
struct ContentView: View {
    @StateObject private var dbManager = DuckDBManager()
    @StateObject private var tabManager = TabManager()
    @State private var selectedFile: URL?
    @AppStorage("recentFiles") private var recentFilesData: Data = Data()
    
    // Zoom (??)
    @State private var currentZoom: CGFloat = 1.0
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 3.0
}
```

**???????**
```swift
private func loadFile(url: URL) {
    selectedFile = url
    addToRecentFiles(url)
    
    if FeatureFlags.tabsEnabled {
        // ???? Tab ????????????? Tab
        if let currentTab = tabManager.currentTab, currentTab.fileURL == nil {
            _ = tabManager.updateCurrentTab(fileURL: url)
        } else {
            if !tabManager.addTab(fileURL: url) {
                // Tab ????
                return
            }
        }
    }
    
    Task {
        await dbManager.loadParquet(url: url)
    }
}
```

**Tab ?????**
```swift
.onChange(of: tabManager.selectedTabID) { newValue in
    if let currentTab = tabManager.currentTab, let fileURL = currentTab.fileURL {
        selectedFile = fileURL
        Task {
            await dbManager.loadParquet(url: fileURL)
        }
    } else {
        selectedFile = nil
        dbManager.clearData()
    }
}
```

**?????**
```
ContentView
??? NavigationSplitView
?   ??? Sidebar (Recent Files + Open button)
?   ??? DetailView
?       ??? TabBarView (if tabsEnabled)
?       ??? DataTableView (with zoom if enabled)
?       ??? WelcomeScreen (if no file)
??? SettingsView (sheet)
```

---

### 3. DataTableView.swift - ??????

**???**
- ???????Header + Rows?
- ?? Freeze Pane???????
- ??????????
- ?????LazyVStack?

**Freeze Pane ???**
```swift
var body: some View {
    VStack(spacing: 0) {
        // Header
        headerRow()
        
        // Data area with Freeze Pane
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                HStack(alignment: .top, spacing: 0) {
                    // FROZEN ROW NUMBERS
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(rows.indices, id: \.self) { index in
                                rowNumberView(index: index)
                                    .id(index)
                            }
                        }
                    }
                    .frame(width: 60)
                    .simultaneousGesture(DragGesture().onChanged { _ in })
                    
                    // SCROLLABLE DATA
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(rows.indices, id: \.self) { index in
                                dataRowView(row: rows[index], index: index)
                                    .id(index)
                                    .onAppear {
                                        scrollProxy.scrollTo(index, anchor: .top)
                                        // Pagination
                                        if index == rows.count - 10 && hasMoreData {
                                            onLoadMore()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

**??????**
```swift
@State private var selectedRow: Int?
@State private var selectedColumn: Int?
@State private var selectionStart: (row: Int, col: Int)?
@State private var selectionEnd: (row: Int, col: Int)?

private func handleCellClick(row: Int, col: Int) {
    if NSEvent.modifierFlags.contains(.shift), selectionStart != nil {
        selectionEnd = (row, col)
    } else {
        selectionStart = (row, col)
        selectionEnd = nil
    }
}

private func copySelection() {
    guard let start = selectionStart else { return }
    
    let end = selectionEnd ?? start
    let rowRange = min(start.row, end.row)...max(start.row, end.row)
    let colRange = min(start.col, end.col)...max(start.col, end.col)
    
    // ?? 100x100
    if rowRange.count > 100 || colRange.count > 100 {
        showCopyAlert = true
        return
    }
    
    // ??????
    let text = rowRange.map { row in
        colRange.map { col in rows[row][col] }.joined(separator: "\t")
    }.joined(separator: "\n")
    
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
```

**?????**
- ? ?? `LazyVStack` ????
- ? `id: \.self` ? `id: \.offset` ?? ID
- ? `.onAppear` ??????????
- ? ??? `LazyVStack` ????????

---

### 4. DuckDBManager.swift - ???

**???**
- DuckDB ????
- Parquet/CSV ????
- SQL ????
- ???????

**?? API?**
```swift
@MainActor
class DuckDBManager: ObservableObject {
    @Published var columns: [String] = []
    @Published var rows: [[String]] = []
    @Published var errorMessage: String?
    @Published var totalRowCount: Int = 0
    @Published var displayedRowCount: Int = 0
    
    private var database: Database?
    private var connection: Connection?
    
    func loadParquet(url: URL, offset: Int = 0, limit: Int = 10000) async {
        // 1. ??? DuckDB
        // 2. ???????Parquet or CSV?
        // 3. ?? SQL ??
        // 4. ??????? @Published ??
    }
    
    func exportToCSV(sourceURL: URL, destinationURL: URL) async -> Bool {
        // Parquet ? CSV ??
    }
    
    func exportToParquet(sourceURL: URL, destinationURL: URL) async -> Bool {
        // CSV ? Parquet ??
    }
    
    func clearData() {
        // ???????? Tab?
    }
}
```

**???????**
```swift
private func detectFileType(url: URL) -> String {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "parquet": return "parquet"
    case "csv", "tsv": return "csv"
    default: return "parquet"  // ??
    }
}
```

**SQL ?????**
```swift
// Parquet
let query = """
    SELECT * FROM read_parquet('\(path)')
    LIMIT \(limit) OFFSET \(offset)
"""

// CSV
let query = """
    SELECT * FROM read_csv_auto('\(path)')
    LIMIT \(limit) OFFSET \(offset)
"""

// Export CSV
let exportQuery = """
    COPY (SELECT * FROM read_parquet('\(sourcePath)'))
    TO '\(destPath)' (FORMAT CSV, HEADER)
"""
```

**?????**
```swift
do {
    let result = try connection.query(query)
    // ...
} catch {
    await MainActor.run {
        errorMessage = "Failed to load file: \(error.localizedDescription)"
    }
}
```

---

### 5. TabManager.swift - ?????

**???**
- ??????? Tabs
- Tab ?????
- Tab ????

**?????**
```swift
struct FileTab: Identifiable, Equatable {
    let id: UUID
    var fileURL: URL?  // nil = ?? Tab
    var displayName: String
    
    init(fileURL: URL?, id: UUID = UUID()) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = fileURL?.lastPathComponent ?? "Untitled"
    }
}

@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [FileTab] = []
    @Published var selectedTabID: UUID?
    @AppStorage("maxTabs") var maxTabs: Int = 10
    
    var currentTab: FileTab? {
        tabs.first(where: { $0.id == selectedTabID })
    }
}
```

**?????**
```swift
func addTab(fileURL: URL?) -> Bool {
    // ?? Tab ??
    guard tabs.count < maxTabs else { return false }
    
    // ???????
    if let existingTab = tabs.first(where: { $0.fileURL == fileURL }) {
        selectedTabID = existingTab.id
        return true
    }
    
    // ??? Tab
    let newTab = FileTab(fileURL: fileURL)
    tabs.append(newTab)
    selectedTabID = newTab.id
    return true
}

func addEmptyTab() {
    _ = addTab(fileURL: nil)
}

func updateCurrentTab(fileURL: URL) -> Bool {
    guard let selectedTabID = selectedTabID,
          let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else {
        return false
    }
    
    // ???? ID??? fileURL
    tabs[index] = FileTab(fileURL: fileURL, id: tabs[index].id)
    return true
}

func closeTab(id: UUID) {
    tabs.removeAll(where: { $0.id == id })
    
    if selectedTabID == id {
        selectedTabID = tabs.first?.id
    }
}
```

---

### 6. BuildConfig.swift - ????

**???**
- ????????Tabs, Zoom?
- ?? App ??????????

**???**
```swift
struct FeatureFlags {
    // ???????????
    @AppStorage("tabsEnabled") static var tabsEnabled: Bool = true
    @AppStorage("zoomEnabled") static var zoomEnabled: Bool = true
    
    // App ???????
    static let appName = "Parquet View Pro"
    static let bundleIdentifier = "com.parquetview.pro"
    static let versionString = "1.0.0 Pro"
}

struct DefaultSettings {
    static let maxTabCount = 10
    static let minTabCount = 1
    static let maxTabCountLimit = 50
}
```

**?????**
```swift
// ContentView.swift
if FeatureFlags.tabsEnabled {
    TabBarView(tabManager: tabManager)
}

if FeatureFlags.zoomEnabled {
    DataTableView(...)
        .scaleEffect(currentZoom)
        .gesture(MagnificationGesture() ...)
}

// ParquetViewApp.swift
if FeatureFlags.tabsEnabled {
    CommandMenu("Tab") { ... }
}
```

---

## ?????

### ?????

```
?????Open File?
    ?
ContentView.loadFile(url:)
    ?
TabManager.addTab() / updateCurrentTab()
    ?
DuckDBManager.loadParquet(url:)
    ?
@Published ???? (columns, rows)
    ?
SwiftUI ??????
    ?
DataTableView ????
```

### ??????

```
App Level (@main)
    ParquetViewApp
    ??? AppDelegate
    
Window Level
    ContentView
    ??? @StateObject dbManager: DuckDBManager
    ??? @StateObject tabManager: TabManager
    ??? @State selectedFile: URL?
    
View Level
    DataTableView
    ??? @State selectedRow
    ??? @State selectionStart/End
    ??? LazyVStack (????)
```

---

## ???????

### NotificationCenter ??

```swift
extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let exportFile = Notification.Name("exportFile")
    static let createEmptyTab = Notification.Name("createEmptyTab")
    static let selectTab = Notification.Name("selectTab")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
}
```

### ???

```
Menu Bar (ParquetViewApp)
    ?
NotificationCenter.default.post(name: .openFile)
    ?
ContentView.onReceive(.openFile)
    ?
??????
```

---

## ??????

### 1. ????
```swift
LazyVStack(spacing: 0) {
    ForEach(rows.indices, id: \.self) { index in
        rowView(index)
            .onAppear {
                // ???????
            }
    }
}
```

**???**
- ????10,000 ? ? ~800MB?vs ??? ~1.8GB?
- ?????< 1 ??vs ??? > 5 ??

### 2. ????
```swift
.onAppear {
    if index == rows.count - 10 && hasMoreData && !isLoadingMore {
        onLoadMore()
    }
}
```

**???**
- ?????10,000 ?
- ?????????????

### 3. DuckDB ????
```swift
// ?? LIMIT + OFFSET
let query = """
    SELECT * FROM read_parquet('\(path)')
    LIMIT \(limit) OFFSET \(offset)
"""
```

**???**
- ????????????
- ???????

### 4. ?? NSHostingView ?? LazyVStack
```swift
// ? ?????????
NSHostingView(rootView: LazyVStack { ... })

// ? ?????? SwiftUI
LazyVStack { ... }
```

---

## ?????

### build_pro.sh ??

**???**
1. Clean build?`swift package clean`?
2. Release build?`swift build -c release`?
3. ?? `.app` bundle
4. ?????????
5. ?? `Info.plist`
6. Self-sign?`codesign --force --deep -s -`?
7. ?? DMG?`hdiutil create`?
8. ?? SHA256

**???**
```
.build/release/Parquet View Pro.app
ParquetViewPro.dmg
ParquetViewPro.dmg.sha256
```

### Info.plist ??

```xml
<key>CFBundleIdentifier</key>
<string>com.parquetview.pro</string>

<key>CFBundleName</key>
<string>Parquet View Pro</string>

<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>parquet</string>
            <string>csv</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
    </dict>
</array>

<key>NSSupportsAutomaticTermination</key>
<false/>
```

---

## ?????

### Localizable.swift

```swift
enum LocalizedString {
    static let openFile = NSLocalizedString("Open File", comment: "")
    static let recentFiles = NSLocalizedString("Recent Files", comment: "")
    static let export = NSLocalizedString("Export", comment: "")
    // ...
}
```

### ????

```swift
Text(LocalizedString.openFile)
Button(LocalizedString.export) { ... }
```

---

## ????

### ??????

1. **????**
   - ? Parquet ??
   - ? CSV ??
   - ? ?????10,000+ ??
   - ? ??????????

2. **Freeze Pane**
   - ? ??????
   - ? ??????
   - ? ????
   - ? ????

3. **???**
   - ? ??????
   - ? Tab ??
   - ? ?? Tab
   - ? Cmd+1-0 ???
   - ? Tab ????

4. **??**
   - ? Parquet ? CSV
   - ? CSV ? Parquet
   - ? ??????

5. **?????**
   - ? ?????
   - ? ??
   - ? ??
   - ? ?????100x100 ???

### ????

| ???? | ?? | ?? | ?? |
|---------|------|------|------|
| ?????10K ?? | < 2s | < 1s | ? |
| ??????10K ?? | < 1GB | ~800MB | ? |
| ?? FPS | 60 | 60 | ? |
| Freeze Pane ?? | < 16ms | < 16ms | ? |

---

## ??????

### ???v1.1?
1. **???????**
   - ???????
   - ?????
   - ????

2. **????**
   - ????min, max, avg?
   - ??????
   - ????

3. **????**
   - Excel ????
   - JSON ????
   - ?????

### ???v1.5?
1. **????**
   - ?????????
   - ?? Excel ? Freeze Panes

2. **????**
   - ???????
   - ???????

3. **????**
   - ??????
   - ?????

### ???v2.0?
1. **????**
   - S3 / Azure Blob ??
   - ????????

2. **????**
   - ????
   - ????

3. **????**
   - ????
   - SQL ????

---

## ?????????

### ????
1. **????**???????? > 100 ???????
2. **???**?? 10,000 ?? 80MB
3. **macOS ??**?????????

### ????
1. ~~AppKit NSScrollView ??~~ ?????
2. ~~PreferenceKey ????~~ ?????
3. ????????columnWidth, rowHeight???????

---

## ????

- [Freeze Pane ????](./FREEZE_PANE_IMPLEMENTATION.md)
- [?????LazyVStack](./PERFORMANCE_FIX_LAZYVSTACK.md)
- [CSV ????](./CSV_SUPPORT_FIX.md)

---

**????**?1.0  
**????**?2025-11-05  
**????**?Parquet View Pro 1.0.0  
**??**?????
