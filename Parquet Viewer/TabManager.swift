// Tab Manager
// Manages multiple file tabs (Pro feature)
// SM-X: Tab Management

import SwiftUI
import Combine

// MARK: - Tab Model

@MainActor
class FileTab: ObservableObject, Identifiable {
    let id: UUID
    @Published var fileURL: URL?
    @Published var displayName: String
    let dbManager: DuckDBManager
    
    init(fileURL: URL?, id: UUID = UUID()) {
        self.id = id
        self.fileURL = fileURL
        self.dbManager = DuckDBManager()
        if let url = fileURL {
            self.displayName = url.lastPathComponent
        } else {
            self.displayName = "tab.untitled".localized
        }
    }
    
    func updateFileURL(_ newURL: URL) {
        self.fileURL = newURL
        self.displayName = newURL.lastPathComponent
    }
}

// MARK: - Tab Manager

@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [FileTab] = []
    @Published var selectedTabID: UUID?
    /// @AppStorage inside an ObservableObject never refreshes (DynamicProperty
    /// update only runs for Views) — read the default directly and re-read on
    /// settings-sheet dismissal via reloadSettings()
    @Published var maxTabs: Int = TabManager.readMaxTabs()

    /// Re-read cached settings (called when the Settings sheet closes)
    func reloadSettings() {
        maxTabs = Self.readMaxTabs()
    }

    private static func readMaxTabs() -> Int {
        let stored = UserDefaults.standard.integer(forKey: "maxTabs")
        return stored > 0 ? stored : DefaultSettings.maxTabCount
    }
    
    var currentTab: FileTab? {
        guard let selectedTabID = selectedTabID else { return nil }
        return tabs.first { $0.id == selectedTabID }
    }
    
    var currentDBManager: DuckDBManager? {
        currentTab?.dbManager
    }
    
    var canAddTab: Bool {
        tabs.count < maxTabs
    }
    
    // MARK: - Tab Operations
    
    func addTab(fileURL: URL?) -> Bool {
        // Check if already open (for non-empty tabs)
        if let fileURL = fileURL,
           let existingTab = tabs.first(where: { $0.fileURL == fileURL }) {
            selectedTabID = existingTab.id
            return true
        }
        
        // Check tab limit
        guard canAddTab else {
            return false
        }
        
        let newTab = FileTab(fileURL: fileURL)
        tabs.append(newTab)
        selectedTabID = newTab.id
        return true
    }
    
    func addEmptyTab() -> Bool {
        return addTab(fileURL: nil)
    }
    
    /// Update the current tab with a file URL (for empty tabs opening files)
    func updateCurrentTab(fileURL: URL) -> Bool {
        guard let selectedTabID = selectedTabID,
              let currentTab = tabs.first(where: { $0.id == selectedTabID }) else {
            return false
        }
        
        // Check if file is already open in another tab
        if let existingTab = tabs.first(where: { $0.fileURL == fileURL }) {
            self.selectedTabID = existingTab.id
            return true
        }
        
        // Update the current tab (keep same ID and dbManager, update fileURL)
        currentTab.updateFileURL(fileURL)
        return true
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        // If closing selected tab, select adjacent tab
        if selectedTabID == id {
            if index > 0 {
                selectedTabID = tabs[index - 1].id
            } else if tabs.count > 1 {
                selectedTabID = tabs[1].id
            } else {
                selectedTabID = nil
            }
        }
        
        tabs.remove(at: index)
    }
    
    func closeAllTabs() {
        tabs.removeAll()
        selectedTabID = nil
    }
    
    func closeOtherTabs(except id: UUID) {
        // Guard: closing "others" around a tab that no longer exists must
        // not wipe everything and select a ghost
        guard tabs.contains(where: { $0.id == id }) else { return }
        tabs.removeAll { $0.id != id }
        selectedTabID = id
    }
    
    func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            selectedTabID = id
        }
    }
    
    func selectNextTab() {
        guard let selectedTabID = selectedTabID,
              let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabID }),
              !tabs.isEmpty else { return }
        
        let nextIndex = (currentIndex + 1) % tabs.count
        self.selectedTabID = tabs[nextIndex].id
    }
    
    func selectPreviousTab() {
        guard let selectedTabID = selectedTabID,
              let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabID }),
              !tabs.isEmpty else { return }
        
        let prevIndex = currentIndex == 0 ? tabs.count - 1 : currentIndex - 1
        self.selectedTabID = tabs[prevIndex].id
    }
}

// MARK: - Tab Bar View

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    var onCreateEmptyTab: () -> Void
    var onCloseOtherTabs: (UUID) -> Void
    var onCloseAllTabs: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabItemView(
                        tab: tab,
                        isSelected: tabManager.selectedTabID == tab.id,
                        onSelect: {
                            tabManager.selectTab(id: tab.id)
                        },
                        onClose: {
                            tabManager.closeTab(id: tab.id)
                        },
                        onCloseOthers: {
                            onCloseOtherTabs(tab.id)
                        },
                        onCloseAll: onCloseAllTabs
                    )
                }
                
                // Add tab button
                if tabManager.canAddTab {
                    Button {
                        onCreateEmptyTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help("tooltip.new_tab".localized)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tab Item View

struct TabItemView: View {
    let tab: FileTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseAll: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            // File icon
            Image(systemName: fileIcon)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            // File name
            Text(tab.displayName)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)
            
            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("menu.close".localized) {
                onClose()
            }
            Button("tab.close_others".localized) {
                onCloseOthers()
            }
            Button("tab.close_all".localized) {
                onCloseAll()
            }
        }
    }
    
    private var fileIcon: String {
        guard let fileURL = tab.fileURL else {
            return "doc.badge.plus"  // Icon for empty/untitled tab
        }
        
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "parquet":
            return "doc.text.fill"
        case "csv", "tsv":
            return "tablecells.fill"
        case "json", "jsonl", "ndjson":
            return "curlybraces.square.fill"
        default:
            return "doc.fill"
        }
    }
}
