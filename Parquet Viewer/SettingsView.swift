// Settings View
// Application preferences and configuration
// SM-13: Settings Panel

import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("language") private var language: Language = .english
    @AppStorage("maxRows") private var maxRows: Int = DataConstants.defaultMaxRows
    @AppStorage("maxTabs") private var maxTabs: Int = DefaultSettings.maxTabCount
    @AppStorage("tabsEnabled") private var tabsEnabled: Bool = true
    @AppStorage("tableFontSize") private var tableFontSize: Double = UIConstants.defaultTableFontSize
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("settings.title".localized)
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
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("alert.cancel".localized)
            }
            .padding()
            
            Divider()
            
            // Settings content
            Form {
                Section("settings.appearance".localized) {
                    Picker("settings.theme".localized, selection: $theme) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.localizedLabel).tag(theme)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("settings.font_size".localizedWithFormat(Int(tableFontSize)))
                            Spacer()
                            Button("button.reset".localized) {
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
                            Text("settings.font_default".localizedWithFormat(Int(UIConstants.defaultTableFontSize)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(UIConstants.maxTableFontSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("settings.font_hint".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("settings.language".localized) {
                    Picker("settings.language.title".localized, selection: $language) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .onChange(of: language) { newValue in
                        UserDefaults.standard.set([newValue.appleLanguageCode], forKey: "AppleLanguages")
                    }

                    Text("settings.language.restart".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("settings.performance".localized) {
                    Stepper("settings.max_rows_value".localizedWithFormat(maxRows),
                           value: $maxRows,
                           in: DataConstants.minMaxRows...DataConstants.maxMaxRows,
                           step: DataConstants.maxRowsStep)

                    Text("settings.max_rows_note".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Feature toggles
                Section("settings.features".localized) {
                    Toggle("settings.multiple_tabs".localized, isOn: $tabsEnabled)

                    Text("settings.relaunch_note".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if tabsEnabled {
                        Stepper("settings.max_tabs_value".localizedWithFormat(maxTabs), 
                                value: $maxTabs, 
                                in: DefaultSettings.minTabCount...DefaultSettings.maxTabCountLimit, 
                                step: 1)
                        
                        Text("settings.max_tabs_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                }
                
                Section("settings.about".localized) {
                    LabeledContent("settings.version".localized, value: FeatureFlags.versionString)
                    LabeledContent("settings.app".localized, value: FeatureFlags.appName)
                    LabeledContent("settings.build".localized, value: "Swift + DuckDB")
                    
                    Divider()
                    
                    DisclosureGroup("settings.shortcuts".localized) {
                        VStack(alignment: .leading, spacing: 8) {
                            ShortcutRow(keys: "⌘O", action: "menu.open_file".localized)
                            ShortcutRow(keys: "⌘F", action: "search.action".localized)
                            ShortcutRow(keys: "⌘+", action: "Increase Font")
                            ShortcutRow(keys: "⌘-", action: "Decrease Font")
                            ShortcutRow(keys: "⌘0", action: "Reset Font")
                            ShortcutRow(keys: "⌘⇧E", action: "Export CSV")
                            ShortcutRow(keys: "⌘⌥E", action: "Export Parquet")
                            if tabsEnabled {
                                Divider()
                                ShortcutRow(keys: "⌘T", action: "menu.new_tab".localized)
                                ShortcutRow(keys: "⌘⇧W", action: "menu.close_tab".localized)
                                ShortcutRow(keys: "⌘1-9", action: "shortcuts.select_tab".localized)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Text("MIT License — see LICENSE in the repository")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
            
            // Footer
            HStack {
                Spacer()
                Button("button.done".localized) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
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

    var localizedLabel: String {
        switch self {
        case .light: return "settings.theme.light".localized
        case .dark: return "settings.theme.dark".localized
        case .system: return "settings.theme.system".localized
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case simplifiedChinese = "简体中文"
    case chineseTraditional = "繁體中文"

    var id: String { rawValue }

    /// AppleLanguages code written on selection; applies after relaunch
    var appleLanguageCode: String {
        switch self {
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        }
    }
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
