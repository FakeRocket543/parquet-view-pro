// Localization Helper
// Provides easy access to localized strings
// SM-12: Internationalization

import Foundation

extension String {
    /// Localized string lookup
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

/// Localization keys
enum L10n {
    // App
    static let appName = "app.name".localized
    
    // Buttons
    static let openFile = "button.open_file".localized
    static let exportCSV = "button.export_csv".localized
    static let settings = "button.settings".localized
    static let done = "button.done".localized
    static let retry = "button.retry".localized
    static let clear = "button.clear".localized
    
    // Welcome
    static let welcomeTitle = "welcome.title".localized
    static let welcomeSubtitle = "welcome.subtitle".localized
    static let welcomeDragDrop = "welcome.drag_drop".localized
    
    // File Info
    static let fileinfoTitle = "fileinfo.title".localized
    static let fileinfoName = "fileinfo.name".localized
    static let fileinfoSize = "fileinfo.size".localized
    static let fileinfoColumns = "fileinfo.columns".localized
    static let fileinfoRows = "fileinfo.rows".localized
    
    // Recent Files
    static let recentTitle = "recent.title".localized
    
    // Search
    static let searchPlaceholder = "search.placeholder".localized
    
    // Loading
    static let loadingMessage = "loading.message".localized
    
    // Error
    static let errorTitle = "error.title".localized
    
    // Settings
    static let settingsTitle = "settings.title".localized
    static let settingsAppearance = "settings.appearance".localized
    static let settingsTheme = "settings.theme".localized
    static let settingsLanguage = "settings.language".localized
    static let settingsPerformance = "settings.performance".localized
    static let settingsAbout = "settings.about".localized
}
