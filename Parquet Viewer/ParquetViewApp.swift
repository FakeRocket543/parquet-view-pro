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
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
            
            CommandGroup(after: .help) {
                Button("About Parquet View") {
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
}

// AppDelegate to ensure app appears in Dock and Cmd+Tab
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to regular app (appears in Dock)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
