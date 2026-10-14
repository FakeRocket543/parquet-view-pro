// Parquet View
// A native macOS app for viewing Parquet files with DuckDB
// SM-5: Main SwiftUI Interface

import SwiftUI

public struct ParquetViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("theme") private var theme: Theme = .system
    
    public init() {}
    
    public var body: some Scene {
        // Single-window scene: with CFBundleDocumentTypes registered, every
        // `open -a` / Finder open used to spawn an ADDITIONAL WindowGroup
        // window (verified: 17 stacked windows after a few opens) instead of
        // loading into the existing tab. Documents route via the AppDelegate
        // `open` handler (onOpenURL would spawn an extra window per doc).
        Window("Parquet View Pro", id: "main") {
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

            // Settings (⌘,) — SwiftUI's Settings scene needs macOS 14;
            // post the existing presentation path instead
            CommandGroup(after: .appSettings) {
                Button("button.settings".localized) {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
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

    // Documents from Finder / `open -a` route into the EXISTING window's
    // tabs via ContentView's .openFileURL subscriber. Do NOT also attach
    // `.onOpenURL` — on macOS, SwiftUI delivers odoc events to onOpenURL by
    // creating an ADDITIONAL window per document (verified: 17 stacked
    // windows after a few opens).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where FileType.isSupported(url) {
            NotificationCenter.default.post(
                name: .openFileURL, object: nil,
                userInfo: ["url": url]
            )
        }
    }

    // Opt out of window restoration: killed sessions piled up multiple
    // stacked, identical windows at the next launch
    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Async sheet, not runModal: a modal run inside this delegate method
        // blocks logout/restart/shutdown
        let alert = NSAlert()
        alert.messageText = "alert.quit.title".localizedWithFormat(FeatureFlags.appName)
        alert.informativeText = "alert.quit.message".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "button.quit".localized)
        alert.addButton(withTitle: "alert.cancel".localized)

        guard let window = sender.windows.first else {
            // No window to host a sheet — modal fallback (rare path)
            return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        alert.beginSheetModal(for: window) { response in
            sender.reply(toApplicationShouldTerminate: response == .alertFirstButtonReturn)
        }
        return .terminateLater
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window is closed (Cmd+W behavior)
        return false
    }
}
