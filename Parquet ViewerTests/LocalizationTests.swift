import XCTest
@testable import ParquetViewLib

final class LocalizationTests: XCTestCase {
    private func languageBundle(_ lproj: String) throws -> Bundle {
        try XCTUnwrap(L10nBundle.bundle(forCode: lproj),
                      "\(lproj).lproj missing from SPM resource bundle")
    }

    private func keys(in lproj: String) throws -> Set<String> {
        let bundle = try languageBundle(lproj)
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return Set(dict.keys)
    }

    func testCompleteLocalesHaveIdenticalKeySets() throws {
        let en = try keys(in: "en")
        let hans = try keys(in: "zh-Hans")
        let hant = try keys(in: "zh-Hant")
        XCTAssertFalse(en.isEmpty)
        XCTAssertEqual(en, hans, "zh-Hans key set drifted from en: +\\(hans.subtracting(en)) -\\(en.subtracting(hans))")
        XCTAssertEqual(en, hant, "zh-Hant key set drifted from en: +\\(hant.subtracting(en)) -\\(en.subtracting(hant))")
    }

    func testLookupResolvesKnownKeyInDefaultState() {
        // Pin English explicitly: without an override the lookup follows the
        // system language, which differs per machine
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        defer { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }

        let value = "settings.title".localized
        XCTAssertNotEqual(value, "settings.title", "lookup must resolve, not return the raw key")
        XCTAssertEqual(value, "Settings")
    }

    func testLookupRespectsSelectedLanguage() throws {
        // All 15 catalogs are at full parity now — verify the AppleLanguages
        // override actually resolves from the selected language's table
        UserDefaults.standard.set(["de"], forKey: "AppleLanguages")
        defer { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }

        let value = "jump.title".localized
        XCTAssertNotEqual(value, "jump.title", "lookup must resolve, not return the raw key")
        XCTAssertNotEqual(value, "Jump to Row", "German table must win over the English fallback")
    }

    func testFormatSpecifiersSurviveAcrossCompleteLocales() throws {
        for lang in ["en", "zh-Hans", "zh-Hant"] {
            let bundle = try languageBundle(lang)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            XCTAssertEqual(dict["search.rows_range"]?.filter { $0 == "%" }.count, 3,
                           "\(lang): search.rows_range must keep 3 format specifiers")
            XCTAssertEqual(dict["csv.issue.mismatch"]?.filter { $0 == "%" }.count, 3,
                           "\(lang): csv.issue.mismatch must keep 3 format specifiers")
        }
    }
}
