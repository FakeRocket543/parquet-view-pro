// Build Configuration
// Single Pro version with user-configurable features
// SM-X: Build Configuration

import Foundation
import SwiftUI

// MARK: - Feature Flags

struct FeatureFlags {
    /// Tab support (can be toggled in settings; takes effect after relaunch)
    @AppStorage("tabsEnabled") static var tabsEnabled: Bool = true

    /// App display name
    static let appName = "Parquet View Pro"
    
    /// Bundle identifier
    static let bundleIdentifier = "com.parquetview.pro"
    
    /// Version string (keep in sync with release notes and Info.plist)
    static let versionString = "1.4.1 Pro"
}

// MARK: - Settings Defaults

struct DefaultSettings {
    /// Default maximum tabs (Pro only)
    static let maxTabCount: Int = 10
    
    /// Minimum tabs (Pro only)
    static let minTabCount: Int = 2
    
    /// Maximum tabs limit (Pro only)
    static let maxTabCountLimit: Int = 20
}
