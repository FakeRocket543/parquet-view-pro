// Settings View
// Application preferences and configuration
// SM-13: Settings Panel

import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("language") private var language: Language = .english
    @AppStorage("maxRows") private var maxRows: Int = 1000
    @AppStorage("uiScale") private var uiScale: Double = 1.0
    @AppStorage("maxTabs") private var maxTabs: Int = DefaultSettings.maxTabCount
    @AppStorage("tabsEnabled") private var tabsEnabled: Bool = true
    @AppStorage("zoomEnabled") private var zoomEnabled: Bool = true
    
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
                }
                
                Section("Language") {
                    Picker("Display Language", selection: $language) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }
                
                Section("Performance") {
                    Stepper("Max Rows to Load: \(maxRows)", value: $maxRows, in: 100...10000, step: 100)
                    
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
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/yourusername/parquet-viewer")!)
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
        .frame(width: 500, height: 500)
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
