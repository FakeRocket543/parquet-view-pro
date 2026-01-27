// Tab Notification Handlers
// Manages tab-related notification observers
// SM-5: Tab Management System

import SwiftUI

/// Tab notification handlers component
/// responsible for setting up and managing tab-related notifications
struct TabNotificationHandlers {
    let tabManager: TabManager
    let openFile: () -> Void
    let setSelectedFile: (URL?) -> Void
    let clearData: () -> Void

    /// Setup all tab-related notification observers
    func setupNotifications() {
        guard FeatureFlags.tabsEnabled else { return }

        // Open file from tab
        NotificationCenter.default.addObserver(
            forName: .openFileFromTab,
            object: nil,
            queue: .main
        ) { _ in
            openFile()
        }

        // Create empty tab
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
                    setSelectedFile(nil)
                    clearData()
                }
            }
        }

        // Close current tab
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

        // Close other tabs
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

        // Close all tabs
        NotificationCenter.default.addObserver(
            forName: .closeAllTabs,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.closeAllTabs()
            }
        }

        // Next tab
        NotificationCenter.default.addObserver(
            forName: .nextTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.selectNextTab()
            }
        }

        // Previous tab
        NotificationCenter.default.addObserver(
            forName: .previousTab,
            object: nil,
            queue: .main
        ) { [weak tabManager] _ in
            Task { @MainActor in
                tabManager?.selectPreviousTab()
            }
        }

        // Select tab by index
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
}
