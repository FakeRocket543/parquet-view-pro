// Parquet View
// A native macOS app for viewing Parquet files with DuckDB
// SM-5: Main SwiftUI Interface

import SwiftUI

public struct ParquetViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("theme") private var theme: Theme = .system
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, idealWidth: 1200, maxWidth: .infinity,
                       minHeight: 600, idealHeight: 800, maxHeight: .infinity)
                .preferredColorScheme(theme.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("menu.open_file".localized) {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("export.as_csv".localized) {
                    NotificationCenter.default.post(name: .exportCSV, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("export.as_parquet".localized) {
                    NotificationCenter.default.post(name: .exportParquet, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
            }

            // Edit Menu
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("menu.find".localized) {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // View Menu — keep the NATIVE Toggle Sidebar item (it drives the
            // NavigationSplitView via columnVisibility); only add font items
            CommandGroup(after: .sidebar) {
                Button("menu.increase_font".localized) {
                    NotificationCenter.default.post(name: .increaseFontSize, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("menu.decrease_font".localized) {
                    NotificationCenter.default.post(name: .decreaseFontSize, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("menu.reset_font".localized) {
                    NotificationCenter.default.post(name: .resetFontSize, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            // Tab menu (when tabs enabled)
            if FeatureFlags.tabsEnabled {
                CommandMenu("menu.tab".localized) {
                    Button("menu.new_tab".localized) {
                        NotificationCenter.default.post(name: .createEmptyTab, object: nil)
                    }
                    .keyboardShortcut("t", modifiers: .command)

                    Divider()

                    Button("menu.close_tab".localized) {
                        NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                    }
                    // ⇧⌘W: ⌘W must stay reserved for closing the window
                    .keyboardShortcut("w", modifiers: [.command, .shift])

                    Button("menu.close_other_tabs".localized) {
                        NotificationCenter.default.post(name: .closeOtherTabs, object: nil)
                    }
                    
                    Button("menu.close_all_tabs".localized) {
                        NotificationCenter.default.post(name: .closeAllTabs, object: nil)
                    }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                    
                    Divider()
                    
                    Button("menu.next_tab".localized) {
                        NotificationCenter.default.post(name: .nextTab, object: nil)
                    }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                    
                    Button("menu.previous_tab".localized) {
                        NotificationCenter.default.post(name: .previousTab, object: nil)
                    }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    // Cmd+1 to Cmd+9 for tabs 1-9, Cmd+0 for tab 10
                    Button("menu.select_tab".localizedWithFormat(1)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 0])
                    }
                    .keyboardShortcut("1", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(2)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 1])
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(3)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 2])
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(4)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 3])
                    }
                    .keyboardShortcut("4", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(5)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 4])
                    }
                    .keyboardShortcut("5", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(6)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 5])
                    }
                    .keyboardShortcut("6", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(7)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 6])
                    }
                    .keyboardShortcut("7", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(8)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 7])
                    }
                    .keyboardShortcut("8", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(9)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 8])
                    }
                    .keyboardShortcut("9", modifiers: .command)
                    
                    Button("menu.select_tab".localizedWithFormat(10)) {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 9])
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }
            }
            
            CommandGroup(after: .help) {
                Button("menu.about".localizedWithFormat(FeatureFlags.appName)) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}

// Theme extension for color scheme
extension Theme {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// AppDelegate to ensure app appears in Dock and Cmd+Tab
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to regular app (appears in Dock)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Show confirmation dialog before quitting (Cmd+Q)
        let alert = NSAlert()
        alert.messageText = "alert.quit.title".localizedWithFormat(FeatureFlags.appName)
        alert.informativeText = "alert.quit.message".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "button.quit".localized)
        alert.addButton(withTitle: "alert.cancel".localized)
        
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window is closed (Cmd+W behavior)
        return false
    }
}
