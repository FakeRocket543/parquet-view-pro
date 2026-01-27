// Parquet View
// A native macOS app for viewing Parquet files with DuckDB
// SM-5: Main SwiftUI Interface

import SwiftUI

@main
struct ParquetViewApp: App {
    // FIXED: Use NSApplicationDelegateAdaptor to set activation policy
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("theme") private var theme: Theme = .system
    
    var body: some Scene {
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
                Button("Open File...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                if FeatureFlags.tabsEnabled {
                    Button("Close Tab") {
                        NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                    }
                    .keyboardShortcut("w", modifiers: .command)
                    
                    Divider()
                }
                
                Button("Export as CSV...") {
                    NotificationCenter.default.post(name: .exportCSV, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Button("Export as Parquet...") {
                    NotificationCenter.default.post(name: .exportParquet, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
            }
            
            // Edit Menu
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find...") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            
            // Replace default View menu
            CommandGroup(replacing: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                
                Divider()
                
                Button("Increase Font Size") {
                    NotificationCenter.default.post(name: .increaseFontSize, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Decrease Font Size") {
                    NotificationCenter.default.post(name: .decreaseFontSize, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Reset Font Size") {
                    NotificationCenter.default.post(name: .resetFontSize, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            // Tab menu (when tabs enabled)
            if FeatureFlags.tabsEnabled {
                CommandMenu("Tab") {
                    Button("New Tab") {
                        NotificationCenter.default.post(name: .createEmptyTab, object: nil)
                    }
                    .keyboardShortcut("t", modifiers: .command)
                    
                    Divider()
                    
                    Button("Close Other Tabs") {
                        NotificationCenter.default.post(name: .closeOtherTabs, object: nil)
                    }
                    
                    Button("Close All Tabs") {
                        NotificationCenter.default.post(name: .closeAllTabs, object: nil)
                    }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                    
                    Divider()
                    
                    Button("Next Tab") {
                        NotificationCenter.default.post(name: .nextTab, object: nil)
                    }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                    
                    Button("Previous Tab") {
                        NotificationCenter.default.post(name: .previousTab, object: nil)
                    }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    // Cmd+1 to Cmd+9 for tabs 1-9, Cmd+0 for tab 10
                    Button("Select Tab 1") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 0])
                    }
                    .keyboardShortcut("1", modifiers: .command)
                    
                    Button("Select Tab 2") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 1])
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    
                    Button("Select Tab 3") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 2])
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    
                    Button("Select Tab 4") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 3])
                    }
                    .keyboardShortcut("4", modifiers: .command)
                    
                    Button("Select Tab 5") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 4])
                    }
                    .keyboardShortcut("5", modifiers: .command)
                    
                    Button("Select Tab 6") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 5])
                    }
                    .keyboardShortcut("6", modifiers: .command)
                    
                    Button("Select Tab 7") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 6])
                    }
                    .keyboardShortcut("7", modifiers: .command)
                    
                    Button("Select Tab 8") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 7])
                    }
                    .keyboardShortcut("8", modifiers: .command)
                    
                    Button("Select Tab 9") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 8])
                    }
                    .keyboardShortcut("9", modifiers: .command)
                    
                    Button("Select Tab 10") {
                        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["index": 9])
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }
            }
            
            CommandGroup(after: .help) {
                Button("About \(FeatureFlags.appName)") {
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

// MARK: - Notification Names

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let exportCSV = Notification.Name("exportCSV")
    static let exportParquet = Notification.Name("exportParquet")
    static let focusSearch = Notification.Name("focusSearch")
    static let increaseFontSize = Notification.Name("increaseFontSize")
    static let decreaseFontSize = Notification.Name("decreaseFontSize")
    static let resetFontSize = Notification.Name("resetFontSize")
    static let toggleSidebar = Notification.Name("toggleSidebar")
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
        alert.messageText = "Quit \(FeatureFlags.appName)?"
        alert.informativeText = "Are you sure you want to quit? All open tabs will be closed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window is closed (Cmd+W behavior)
        return false
    }
}
