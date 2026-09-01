import XCTest
@testable import ParquetViewLib

/// Unit tests for pure logic that previously had zero coverage
final class LogicTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    // MARK: FileType SQL shapes (the entire app's queries are built on these)

    func testFromClauseShapes() {
        XCTAssertEqual(FileType.parquet.fromClause(path: "p"), "read_parquet('p')")
        XCTAssertEqual(FileType.csv.fromClause(path: "p"),
                       "read_csv('p', ignore_errors=true, auto_detect=true)")
        XCTAssertEqual(FileType.tsv.fromClause(path: "p"),
                       "read_csv('p', delim='\t', ignore_errors=true, auto_detect=true)")
        XCTAssertEqual(FileType.json.fromClause(path: "p"), "read_json_auto('p')")
        XCTAssertEqual(FileType.jsonl.fromClause(path: "p"),
                       "read_json_auto('p', format='newline_delimited')")
    }

    func testFileTypeDetectionIncludingUppercaseAndNdjson() {
        func type(_ path: String) -> FileType? {
            FileType.from(url: URL(fileURLWithPath: path))
        }
        XCTAssertEqual(type("/x/a.parquet"), .parquet)
        XCTAssertEqual(type("/x/a.PARQUET"), .parquet)   // uppercase
        XCTAssertEqual(type("/x/a.csv"), .csv)
        XCTAssertEqual(type("/x/a.tsv"), .tsv)
        XCTAssertEqual(type("/x/a.json"), .json)
        XCTAssertEqual(type("/x/a.jsonl"), .jsonl)
        XCTAssertEqual(type("/x/a.ndjson"), .jsonl)      // alias
        XCTAssertEqual(type("/x/a.NDJSON"), .jsonl)
        XCTAssertNil(type("/x/a.txt"))
    }

    // MARK: Delimiter sniffing (checker must agree with DuckDB's dialect sniffing)

    func testSniffDelimiterPicksDominantIgnoringQuoted() {
        XCTAssertEqual(CSVIntegrityChecker.sniffDelimiter(in: "a;b;c", fallback: ","), ";")
        XCTAssertEqual(CSVIntegrityChecker.sniffDelimiter(in: "a\tb;c\td", fallback: ","), "\t")
        XCTAssertEqual(CSVIntegrityChecker.sniffDelimiter(in: "\"a,b\";c", fallback: ","), ";",
                       "quoted comma must not count")
        XCTAssertEqual(CSVIntegrityChecker.sniffDelimiter(in: "solo", fallback: ","), ",",
                       "no delimiters → fallback")
        XCTAssertEqual(CSVIntegrityChecker.sniffDelimiter(in: "a|b|c", fallback: ","), "|")
    }

    // MARK: Repair actions must resolve against the localization table

    func testRepairActionDescriptionsResolve() {
        let cases: [(CSVRepairAction, String)] = [
            (.ignoreAndLoad, "csv.action.ignore_and_load"),
            (.skipLastRow, "csv.action.skip_last_row"),
            (.openWithExternalTool, "csv.action.open_external"),
            (.retryWithDifferentSettings, "csv.action.retry_settings"),
        ]
        for (action, key) in cases {
            XCTAssertNotEqual(action.description, key,
                              "\(key) leaked as a raw dotted key in the repair dialog")
            XCTAssertFalse(action.icon.isEmpty)
        }
    }
}
