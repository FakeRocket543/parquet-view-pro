// Localizable.swift
// Bundle-aware localization lookup for SPM resource bundles.
//
// SwiftUI's Text("literal") resolves against Bundle.main, but the .strings
// tables live in the SPM-generated ParquetViewLib resource bundle — so all
// lookups here go through Bundle.module (with the user's AppleLanguages
// override applied) and fall back to English when a key is missing in the
// selected language.

import Foundation

enum L10nBundle {
    /// Resource bundle containing the .lproj tables (SPM generates this).
    static let module: Bundle = Bundle.module

    /// The user's preferred language (Settings ▸ Language writes
    /// AppleLanguages; requires an app restart to take effect).
    static var preferredCode: String? {
        UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
    }

    /// Resolve an .lproj inside the SPM resource bundle. SPM lowercases
    /// directory names (zh-Hans → zh-hans), so try canonical, underscored
    /// and lowercased spellings.
    static func bundle(forCode code: String) -> Bundle? {
        let candidates = [
            code,
            code.replacingOccurrences(of: "-", with: "_"),
            code.lowercased(),
            code.replacingOccurrences(of: "-", with: "_").lowercased(),
        ]
        for candidate in candidates {
            if let path = module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    /// English fallback table.
    static let enFallback: Bundle = bundle(forCode: "en") ?? module

    /// Preferred table, memoized per AppleLanguages value — the expensive
    /// path scan only reruns when the preference actually changes.
    private static var cachedKey: [String] = []
    private static var cachedBundle: Bundle = resolvePreferred([])

    private static func resolvePreferred(_ codes: [String]) -> Bundle {
        for code in codes {
            guard !code.isEmpty else { continue }
            // Progressively strip region qualifiers: zh-Hans-CN → zh-Hans → zh
            var candidate = code
            for _ in 0...1 {
                if let b = bundle(forCode: candidate), b !== enFallback {
                    return b
                }
                if let idx = candidate.lastIndex(of: "-") {
                    candidate = String(candidate[..<idx])
                } else {
                    break
                }
            }
        }
        return enFallback
    }

    /// Bundle for the preferred language, or the English fallback table.
    static var preferred: Bundle {
        let codes = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
        if codes != cachedKey {
            cachedKey = codes
            cachedBundle = resolvePreferred(codes)
        }
        return cachedBundle
    }
}

extension String {
    /// Localized value for this key. Two-stage lookup: preferred language
    /// table first, English table when the key is missing there (so locales
    /// that lag behind the key catalog degrade to English instead of showing
    /// raw dotted keys).
    var localized: String {
        let preferredBundle = L10nBundle.preferred
        let value = preferredBundle.localizedString(forKey: self, value: self, table: nil)
        if value != self || preferredBundle === L10nBundle.enFallback {
            if value != self { return value }
            // key missing in en too
            return self
        }
        let enValue = L10nBundle.enFallback.localizedString(forKey: self, value: self, table: nil)
        return enValue != self ? enValue : self
    }

    /// Localized format string applied to arguments, e.g.
    /// "search.rows_range".localizedWithFormat(1, 100, 5000)
    func localizedWithFormat(_ args: CVarArg...) -> String {
        String(format: localized, locale: Locale.current, arguments: args)
    }
}
