// Settings View
// Application preferences and configuration
// SM-13: Settings Panel

import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("language") private var language: Language = .english
    @AppStorage("maxRows") private var maxRows: Int = DataConstants.defaultMaxRows
    @AppStorage("uiScale") private var uiScale: Double = 1.0
    @AppStorage("maxTabs") private var maxTabs: Int = DefaultSettings.maxTabCount
    @AppStorage("tabsEnabled") private var tabsEnabled: Bool = true
    @AppStorage("zoomEnabled") private var zoomEnabled: Bool = true
    @AppStorage("tableFontSize") private var tableFontSize: Double = UIConstants.defaultTableFontSize
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Settings content
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Slider(value: $uiScale, in: 0.8...1.5, step: 0.1) {
                        Text("UI Scale: \(String(format: "%.1f", uiScale))x")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Table Font Size: \(Int(tableFontSize)) pt")
                            Spacer()
                            Button("Reset") {
                                tableFontSize = UIConstants.defaultTableFontSize
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }

                        Slider(value: $tableFontSize,
                              in: UIConstants.minTableFontSize...UIConstants.maxTableFontSize,
                              step: 1)

                        HStack {
                            Text("\(Int(UIConstants.minTableFontSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(UIConstants.defaultTableFontSize)) (Default)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(UIConstants.maxTableFontSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Use Cmd +/- or Cmd 0 to adjust font size in the table")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Language") {
                    Picker("Display Language", selection: $language) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }
                
                Section("Performance") {
                    Stepper("Max Rows to Load: \(maxRows)",
                           value: $maxRows,
                           in: DataConstants.minMaxRows...DataConstants.maxMaxRows,
                           step: DataConstants.maxRowsStep)

                    Text("Higher values may impact performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Feature toggles
                Section("Features") {
                    Toggle("Enable Multiple Tabs", isOn: $tabsEnabled)
                    
                    if tabsEnabled {
                        Stepper("Maximum Tabs: \(maxTabs)", 
                                value: $maxTabs, 
                                in: DefaultSettings.minTabCount...DefaultSettings.maxTabCountLimit, 
                                step: 1)
                        
                        Text("Maximum number of tabs that can be opened simultaneously")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Toggle("Enable Zoom", isOn: $zoomEnabled)
                    
                    Text("Allow pinch-to-zoom and Cmd+/- shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("About") {
                    LabeledContent("Version", value: FeatureFlags.versionString)
                    LabeledContent("App", value: FeatureFlags.appName)
                    LabeledContent("Build", value: "Swift + DuckDB")
                    
                    Divider()
                    
                    DisclosureGroup("Keyboard Shortcuts") {
                        VStack(alignment: .leading, spacing: 8) {
                            ShortcutRow(keys: "⌘O", action: "Open File")
                            ShortcutRow(keys: "⌘F", action: "Search")
                            ShortcutRow(keys: "⌘+", action: "Increase Font")
                            ShortcutRow(keys: "⌘-", action: "Decrease Font")
                            ShortcutRow(keys: "⌘0", action: "Reset Font")
                            ShortcutRow(keys: "⌘⇧E", action: "Export CSV")
                            ShortcutRow(keys: "⌘⌥E", action: "Export Parquet")
                            if tabsEnabled {
                                Divider()
                                ShortcutRow(keys: "⌘T", action: "New Tab")
                                ShortcutRow(keys: "⌘W", action: "Close Tab")
                                ShortcutRow(keys: "⌘1-9", action: "Select Tab")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if let githubURL = URL(string: "https://github.com/yourusername/parquet-viewer") {
                        Link("GitHub Repository", destination: githubURL)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: UIConstants.settingsWindowWidth, height: UIConstants.settingsWindowHeight)
    }
}

// MARK: - Enums

enum Theme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { rawValue }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case chineseTraditional = "????"
    
    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

// MARK: - Helper Views

struct ShortcutRow: View {
    let keys: String
    let action: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 80, alignment: .leading)
            Text(action)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
