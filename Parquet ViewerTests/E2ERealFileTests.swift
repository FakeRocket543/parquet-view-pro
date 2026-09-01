import XCTest
@testable import ParquetViewLib
import DuckDB

/// End-to-end tests: real files (generated via DuckDB itself) driven through
/// the real DuckDBManager, covering type fidelity, pagination, filtering,
/// sorting, format handling and security edge cases.
final class E2ERealFileTests: XCTestCase {
    static var fixtureDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PVE2EFixtures")
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try? FileManager.default.removeItem(at: Self.fixtureDir)
        try FileManager.default.createDirectory(at: Self.fixtureDir, withIntermediateDirectories: true)
        // Determinism: page size and language must not depend on the
        // developer machine's defaults
        UserDefaults.standard.removeObject(forKey: "maxRows")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "maxRows")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    /// Write a real parquet file through DuckDB (same engine the app reads with).
    private func makeParquet(_ name: String, sql: String) throws -> URL {
        let db = try Database(store: .inMemory)
        let conn = try db.connect()
        let url = Self.fixtureDir.appendingPathComponent(name)
        let escapedPath = url.path.replacingOccurrences(of: "'", with: "''")
        try conn.execute("COPY (\(sql)) TO '\(escapedPath)' (FORMAT 'parquet')")
        return url
    }

    private func write(_ name: String, _ content: String) throws -> URL {
        let url = Self.fixtureDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Type fidelity

    func testParquetTypeFidelity() async throws {
        let url = try makeParquet("types.parquet", sql: """
            SELECT
              0.5 AS d_half, 0.05 AS d_005, 0.0000000001 AS d_tiny,
              100.0 AS d_whole, 123.456789 AS d_prec, -0.25 AS d_neg,
              42::BIGINT AS i_big, true AS b_flag, 'hello' AS s_txt,
              NULL::VARCHAR AS s_null,
              TIMESTAMP '2024-06-15 10:30:00' AS ts, DATE '2024-06-15' AS dt,
              DECIMAL(10,2) '99.99' AS dec,
              [1,2,3] AS lst, {'a': 1, 'b': 'x'} AS st,
              18446744073709551615::UBIGINT AS u_max
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.rows.count, 1)

        func cell(_ col: String) -> String {
            let ci = try! XCTUnwrap(mgr.columns.firstIndex(of: col), "missing column \(col)")
            return mgr.rows[0][ci]
        }
        // Decimal-typed values must survive formatting (no mangling, no NULL)
        XCTAssertEqual(cell("d_half"), "0.5")
        XCTAssertEqual(cell("d_005"), "0.05")
        XCTAssertEqual(cell("d_tiny"), "0.0000000001")
        XCTAssertEqual(cell("d_whole"), "100.0")
        XCTAssertEqual(cell("d_prec"), "123.456789")
        XCTAssertEqual(cell("d_neg"), "-0.25")
        // Integers / bool / string / null
        XCTAssertEqual(cell("i_big"), "42")
        XCTAssertEqual(cell("b_flag"), "true")
        XCTAssertEqual(cell("s_txt"), "hello")
        XCTAssertEqual(cell("s_null"), "NULL")
        // Temporal / decimal / nested / unsigned
        XCTAssertEqual(cell("ts"), "2024-06-15 10:30:00")
        XCTAssertEqual(cell("dt"), "2024-06-15")
        XCTAssertEqual(cell("dec"), "99.99")
        XCTAssertEqual(cell("lst"), "[1, 2, 3]")
        XCTAssertEqual(cell("u_max"), "18446744073709551615")
    }

    // MARK: - Pagination

    func testPaginationAndRowAlignment() async throws {
        let url = try makeParquet("big.parquet", sql: """
            SELECT i, 'row ' || i AS label FROM range(1, 100001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertEqual(mgr.totalRowCount, 100000)
        XCTAssertEqual(mgr.displayedRowCount, 1000)

        await mgr.loadMoreData()
        XCTAssertEqual(mgr.displayedRowCount, 2000)
        let iIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "i"))
        XCTAssertEqual(mgr.rows[1000][iIdx], "1001", "row 1001 must align to i=1001 after loadMoreData")

        await mgr.jumpToRow(50000)
        XCTAssertEqual(mgr.rows[0][iIdx], "50000", "jumpToRow(50000) must start at i=50000")
    }

    // MARK: - Sort

    func testSortDescending() async throws {
        let url = try makeParquet("big.parquet", sql: """
            SELECT i FROM range(1, 100001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        await mgr.sortByColumn("i", ascending: false)
        let iIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "i"))
        XCTAssertEqual(mgr.rows[0][iIdx], "100000")
        XCTAssertEqual(mgr.rows[1][iIdx], "99999")
    }

    // MARK: - Filter

    func testFilterFindsMatchingRowsOnly() async throws {
        let url = try makeParquet("big.parquet", sql: """
            SELECT i, 'row ' || i AS label FROM range(1, 100001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        await mgr.filterData(searchText: "row 7")
        XCTAssertGreaterThan(mgr.displayedRowCount, 0)
        let labelIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "label"))
        XCTAssertTrue(mgr.rows.allSatisfy { $0[labelIdx].contains("row 7") },
                      "every displayed row must match the filter")
    }

    // MARK: - CSV family

    func testCSVQuotedFieldsWithDelimitersAndEscapedQuotes() async throws {
        let url = try write("quotes.csv", "id,name,note\n1,\"Smith, John\",\"Quote \"\"Q\"\"\"\n2,plain,plain\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.columns, ["id", "name", "note"])
        XCTAssertEqual(mgr.rows[0][1], "Smith, John")
        XCTAssertEqual(mgr.rows[0][2], "Quote \"Q\"")
    }

    func testCSVWithBOMHasCleanHeader() async throws {
        let url = try write("bom.csv", "\u{FEFF}id,name\n1,alpha\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertEqual(mgr.columns.first, "id", "BOM must not leak into column names")
    }

    // MARK: - JSON family

    func testJSONLAndJSONLoad() async throws {
        let jsonl = try write("data.jsonl", "{\"a\": 1, \"b\": \"x\"}\n{\"a\": 2, \"b\": \"y\"}\n")
        let m1 = DuckDBManager()
        await m1.loadParquet(url: jsonl)
        XCTAssertEqual(m1.rows.count, 2)

        let json = try write("data.json", "[{\"a\": 1}, {\"a\": 2}]")
        let m2 = DuckDBManager()
        await m2.loadParquet(url: json)
        XCTAssertEqual(m2.rows.count, 2)
    }

    // MARK: - Filter / sort / pagination interplay (regression)

    func testSortKeepsActiveFilterAndLoadMoreStaysFiltered() async throws {
        let url = try makeParquet("filtered.parquet", sql: """
            SELECT i, CASE WHEN i % 3 = 0 THEN 'match 3' ELSE 'other' END AS tag
            FROM range(1, 10001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)

        // Filter
        await mgr.filterData(searchText: "match 3")
        let tagIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "tag"))
        XCTAssertTrue(mgr.rows.allSatisfy { $0[tagIdx] == "match 3" })
        // totalRowCount must reflect the filtered set, not the whole file
        XCTAssertEqual(mgr.totalRowCount, 3333)

        // Sorting while filtered must keep the filter
        await mgr.sortByColumn("i", ascending: false)
        XCTAssertTrue(mgr.rows.allSatisfy { $0[tagIdx] == "match 3" },
                      "sort must not discard the active filter")
        XCTAssertEqual(mgr.rows.first?[mgr.columns.firstIndex(of: "i")!], "9999")

        // Load-more while filtered must append only matching rows
        let before = mgr.rows.count
        await mgr.loadMoreData()
        XCTAssertTrue(mgr.rows.allSatisfy { $0[tagIdx] == "match 3" },
                      "loadMoreData must not mix unfiltered rows into a filtered result")
        XCTAssertGreaterThan(mgr.rows.count, before)

        // Clearing the filter restores the unfiltered view
        await mgr.filterData(searchText: "")
        XCTAssertEqual(mgr.totalRowCount, 10000)
    }

    // MARK: - CSV/TSV integrity edge cases

    func testTSVWithCommaInFieldLoads() async throws {
        // A TSV whose text field contains commas must not be flagged by the
        // comma-based integrity heuristics
        let url = try write("commas.tsv", "id\tdesc\tval\n1\tSmith, John\t10\n2\tplain\t20\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertNil(mgr.csvIssueResult, "valid TSV must not trip the integrity check")
        XCTAssertEqual(mgr.rows.count, 2)
        XCTAssertEqual(mgr.columns, ["id", "desc", "val"])
    }

    func testCSVWithEmbeddedNewlineInQuotesIsValid() async throws {
        // RFC 4180: quoted fields may contain newlines
        let url = try write("multiline.csv", "id,note\n1,\"line one\nline two\"\n2,plain\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.csvIssueResult, "quoted embedded newline must pass the integrity check")
        XCTAssertEqual(mgr.rows.count, 2, "err=\(mgr.errorMessage ?? "-")")
    }

    func testTruncatedCSVRaisesIssueResultForUI() async throws {
        let url = try write("truncated.csv", "a,b\n1,2\n3,4\n5")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        let issue = try XCTUnwrap(mgr.csvIssueResult,
                                  "csvIssueResult must be published so the UI can offer repair")
        XCTAssertEqual(issue.issueType, .truncatedLastRow)
        // "Ignore and load" path must work (DuckDB tolerant read)
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage)
    }

    func testFilterEscapesLikeWildcards() async throws {
        // '%' and '_' must be treated literally, not as wildcards
        let url = try makeParquet("wildcards.parquet", sql: """
            SELECT * FROM (VALUES ('100%'), ('100x'), ('a_b'), ('axb')) t(v)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertEqual(mgr.rows.count, 4)

        await mgr.filterData(searchText: "100%")
        XCTAssertEqual(mgr.rows.count, 1, "'%' must be literal, not match '100x'")
        XCTAssertEqual(mgr.rows[0][0], "100%")

        await mgr.filterData(searchText: "a_b")
        XCTAssertEqual(mgr.rows.count, 1, "'_' must be literal, not match 'axb'")
        XCTAssertEqual(mgr.rows[0][0], "a_b")
    }

    // MARK: - Concurrency / memory / failure-resilience (round 2)

    func testConcurrentOperationsDoNotCrashAndLastStateWins() async throws {
        let url = try makeParquet("hammer.parquet", sql: """
            SELECT i, 'row ' || i AS label FROM range(1, 50001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)

        // Hammer the shared manager with overlapping operations — the
        // serialized connection + generation superseding must keep this safe
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                let op = i % 4
                group.addTask {
                    switch op {
                    case 0: await mgr.filterData(searchText: "row 7")
                    case 1: await mgr.sortByColumn("i", ascending: i % 8 == 0)
                    case 2: await mgr.loadMoreData()
                    default: await mgr.jumpToRow(1 + (i * 137) % 40000)
                    }
                }
            }
        }

        // A final awaited operation gives a deterministic end state
        await mgr.filterData(searchText: "row 7")
        XCTAssertNil(mgr.errorMessage)
        XCTAssertGreaterThan(mgr.rows.count, 0)
        let labelIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "label"))
        XCTAssertTrue(mgr.rows.allSatisfy { $0[labelIdx].contains("row 7") },
                      "final state must come from the final operation")
    }

    func testSlidingWindowCapsMemoryAndKeepsAbsoluteRowNumbers() async throws {
        let url = try makeParquet("window.parquet", sql: """
            SELECT i FROM range(1, 25001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.rows.count, 1000)

        // Keep loading past the window cap (max(maxRows*10, 10_000))
        for _ in 0..<12 { await mgr.loadMoreData() }

        XCTAssertLessThanOrEqual(mgr.rows.count, 10_000, "window cap must hold")
        let iIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "i"))
        // Window must have slid forward coherently: first row = startRow+1
        let first = Int(mgr.rows.first?[iIdx] ?? "") ?? -1
        let last = Int(mgr.rows.last?[iIdx] ?? "") ?? -1
        XCTAssertEqual(first, mgr.currentStartRow + 1,
                       "first displayed row must match currentStartRow")
        // ...and rows must be consecutive (no gaps from the slide)
        XCTAssertEqual(last - first + 1, mgr.rows.count)
        XCTAssertNil(mgr.errorMessage)
    }

    func testFailedReloadPreservesPreviousData() async throws {
        let good = try write("good.csv", "id,name\n1,alpha\n2,beta\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: good, skipIntegrityCheck: true)
        XCTAssertEqual(mgr.rows.count, 2)
        XCTAssertNil(mgr.errorMessage)

        // Now attempt a load that fails validation
        let bad = try write("bad.txt", "not a supported file")
        await mgr.loadParquet(url: bad)

        XCTAssertNotNil(mgr.errorMessage)
        XCTAssertEqual(mgr.rows.count, 2, "failed reload must not wipe the visible data")
        XCTAssertEqual(mgr.columns, ["id", "name"])
        XCTAssertTrue(mgr.hasLoadedFile)
    }

    // MARK: - Adversarial regressions (round 2)

    func testHeaderlessCSVDoesNotLoseFirstRow() async throws {
        // No header row: auto-detect must not eat the first data row
        let url = try write("nohead.csv", "1,2\n3,4\n5,6\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage, "\(mgr.errorMessage ?? "")")
        XCTAssertEqual(mgr.rows.count, 3, "all 3 rows must survive")
    }

    func testSemicolonCSVAutoDetectsDelimiter() async throws {
        // European-style CSV saved as .csv must not collapse into 1 column
        let url = try write("semi.csv", "a;b;c\n1;2;3\n4;5;6\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.columns.count, 3, "got \(mgr.columns)")
        XCTAssertEqual(mgr.rows.count, 2)
    }

    func testUTF16CSVLoadsCorrectly() async throws {
        // UTF-16LE with BOM: must decode via the explicit encoding, not
        // render NUL-laden garbage
        let url = Self.fixtureDir.appendingPathComponent("utf16.csv")
        let fields = ["id,name\n", "1,alpha\n", "2,beta\n"]
        var data = Data([0xFF, 0xFE])
        let encoder = String.Encoding.utf16LittleEndian
        for field in fields {
            data.append(field.data(using: encoder)!)
        }
        try data.write(to: url)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage, "\(mgr.errorMessage ?? "")")
        XCTAssertEqual(mgr.columns.first, "id", "got \(mgr.columns)")
        XCTAssertEqual(mgr.rows.count, 2)
        XCTAssertEqual(mgr.rows.first?.last, "alpha")
    }

    func testCountConvergenceWhenSnifferDropsBadRows() async throws {
        // A bad row beyond the sniffer sample window makes COUNT(*) overcount;
        // after the final empty page, hasMoreData must converge to false
        var content = "a,b\n"
        for i in 0..<3000 { content += "\(i),\(i * 2)\n" }
        content += "xx,yy\n"      // unparseable → dropped by ignore_errors
        let url = try write("drift.csv", content)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, limit: 1500, skipIntegrityCheck: true)
        XCTAssertNil(mgr.errorMessage)

        await mgr.loadMoreData()
        // Second page covers the rest; if a further page comes back empty
        // the count must converge instead of looping forever
        let before = mgr.hasMoreData
        if before {
            await mgr.loadMoreData()
        }
        XCTAssertFalse(mgr.hasMoreData, "pagination must terminate at end of data")
    }

    func testJumpToLastRowsHasNoMoreData() async throws {
        let url = try makeParquet("taillight.parquet", sql: """
            SELECT i FROM range(1, 1501) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        // Jump to the final row: window already ends at totalRowCount
        await mgr.jumpToRow(1500)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertFalse(mgr.hasMoreData, "no dead load-more affordance at EOF")
    }

    // MARK: - Regression-verify pins (round 2)

    func testJumpThenLoadMoreContinuesFromJumpPosition() async throws {
        // Pins the absolute-offset fix: old code resumed pagination from
        // displayedRowCount (1000) after a jump, re-loading rows 1001-2000
        let url = try makeParquet("jumpmore.parquet", sql: """
            SELECT i FROM range(1, 100001) t(i)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        await mgr.jumpToRow(50000)
        await mgr.loadMoreData()
        let iIdx = try XCTUnwrap(mgr.columns.firstIndex(of: "i"))
        XCTAssertEqual(mgr.rows.count, 2000)
        XCTAssertEqual(mgr.rows[1000][iIdx], "51000",
                       "page after jump must continue at the jump window's end (i=50000..50999)")
    }

    func testSQLFailureKeepsPreviousFileCurrent() async throws {
        // A file that passes validation but fails inside DuckDB must not
        // become the manager's current file (exports would target it while
        // the screen still shows the previous file's rows)
        let good = try makeParquet("good.parquet", sql: "SELECT 1 AS x")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: good)
        XCTAssertEqual(mgr.rows.count, 1)

        let corrupt = try write("corrupt.parquet", "PAR1 this is not a real parquet payload")
        await mgr.loadParquet(url: corrupt)

        XCTAssertNotNil(mgr.errorMessage)
        XCTAssertEqual(mgr.currentFileURL?.lastPathComponent, "good.parquet",
                       "failed load must not steal currentFileURL")
        XCTAssertEqual(mgr.rows.count, 1, "previous data stays visible")
    }

    func testSecondFileInSameManagerResetsFilterAndSort() async throws {
        let a = try write("fileA.csv", "id,tag\n1,alpha\n2,beta\n3,gamma\n")
        let b = try write("fileB.csv", "id,note\n1,xx\n2,yy\n3,zz\n")

        let mgr = DuckDBManager()
        await mgr.loadParquet(url: a, skipIntegrityCheck: true)
        await mgr.filterData(searchText: "beta")
        await mgr.sortByColumn("tag", ascending: false)
        XCTAssertEqual(mgr.totalRowCount, 1)

        // Different file into the same manager: no inherited filter/sort
        await mgr.loadParquet(url: b, skipIntegrityCheck: true)
        XCTAssertNil(mgr.activeFilterText, "filter must not leak into the next file")
        XCTAssertNil(mgr.sortColumn, "sort must not leak into the next file")
        XCTAssertEqual(mgr.totalRowCount, 3, "count must reflect the unfiltered new file")
        XCTAssertEqual(mgr.rows.count, 3)
    }

    func testColumnNameContainingQuoteLoadsSortsAndFilters() async throws {
        // Column names come from untrusted headers — quoting must survive
        let url = try makeParquet("quoted.parquet", sql: """
            SELECT 1 AS "a""b", 'v1' AS plain
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage, "\(mgr.errorMessage ?? "")")
        XCTAssertTrue(mgr.columns.contains("a\"b"), "got \(mgr.columns)")

        await mgr.sortByColumn("a\"b", ascending: true)
        XCTAssertNil(mgr.errorMessage, "sort on quoted name must not break SQL")

        await mgr.filterData(searchText: "v1", column: "plain")
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.rows.count, 1)
    }

    // MARK: - Round 3 regressions

    func testSemicolonCSVPassesIntegrityCheckWithoutSkip() async throws {
        // Sniffer-friendly dialect must also pass the integrity checker
        // (comma-based heuristics used to flag valid semicolon files)
        let url = try write("semi2.csv", "a;b;c\n1;2;3\n4;5,5;6\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)  // integrity check NOT skipped
        XCTAssertNil(mgr.csvIssueResult, "semicolon file with a comma inside a field is valid")
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.columns, ["a", "b", "c"])
        XCTAssertEqual(mgr.rows.count, 2)
    }

    func testCheckerHandlesFilesAroundCapBoundary() throws {
        // Exactly at the 2 MB cap: file size == bytes read → NOT truncated →
        // the final record must be judged, not dropped
        let cap = CSVIntegrityChecker.maxCheckBytes
        let lineSize = 100
        let header = "id,pad\n"

        func line(pad: Character, id: String, size: Int) -> String {
            var l = "\(id),\(pad)"
            while l.utf8.count < size - 1 { l.append(pad) }
            l += "\n"
            return l
        }

        let remaining = cap - header.utf8.count
        let wholeLines = remaining / lineSize
        let extra = remaining % lineSize

        var exact = header
        for _ in 0..<wholeLines { exact += line(pad: "p", id: "0", size: lineSize) }
        if extra >= 4 {
            exact += line(pad: "q", id: "1", size: extra)
        }
        XCTAssertEqual(exact.utf8.count, cap, "fixture must be exactly cap-sized")

        let url = try write("exact2mb.csv", exact)
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertTrue(result.isValid, "exact-cap valid file must not be flagged: \(String(describing: result.issueType))")

        // One byte over the cap: hitCap true → the (complete) tail record is
        // dropped as unjudgeable, everything else valid → still valid
        var over = exact
        over.removeLast()  // drop "\n"
        over += "q\n"      // same record, one byte longer → total = cap + 1
        XCTAssertEqual(over.utf8.count, cap + 1)

        let urlOver = try write("over2mb.csv", over)
        let resultOver = CSVIntegrityChecker.check(url: urlOver)
        XCTAssertTrue(resultOver.isValid, "cap+1 valid file must not be flagged: \(String(describing: resultOver.issueType))")
    }

    func testBatchedColumnStatsAreCorrect() async throws {
        let url = try makeParquet("stats.parquet", sql: """
            SELECT * FROM (VALUES
                (10, 'a'), (20, 'b'), (30, 'a'), (NULL, NULL)
            ) t(n, s)
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)

        await mgr.loadColumnStats()
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.columnStats["n"]?.nullCount, 1)
        XCTAssertEqual(mgr.columnStats["n"]?.uniqueCount, 3)
        XCTAssertEqual(mgr.columnStats["n"]?.minValue, "10")
        XCTAssertEqual(mgr.columnStats["n"]?.maxValue, "30")
        XCTAssertEqual(mgr.columnStats["n"]?.avgValue, "20.0000")
        XCTAssertEqual(mgr.columnStats["s"]?.nullCount, 1)
        XCTAssertEqual(mgr.columnStats["s"]?.uniqueCount, 2)
    }

    // MARK: - Security

    func testExoticFilePathsLoad() async throws {
        // Filenames with SQL-meaningful characters must load (quote escaped,
        // backslash preserved — not doubled by sanitization)
        let apostrophe = try makeParquet("it's data.parquet", sql: "SELECT 1 AS x")
        let m1 = DuckDBManager()
        await m1.loadParquet(url: apostrophe)
        XCTAssertNil(m1.errorMessage, "apostrophe filename must load: \(m1.errorMessage ?? "")")

        let backslash = try makeParquet("back\\slash.parquet", sql: "SELECT 2 AS x")
        let m2 = DuckDBManager()
        await m2.loadParquet(url: backslash)
        XCTAssertNil(m2.errorMessage, "backslash filename must load: \(m2.errorMessage ?? "")")
    }

    func testDoubleTypeRendering() async throws {
        // Explicit DOUBLE (not decimal) column: formatting must not mangle
        // fractional values (0.5 must not render as "5", tiny values not as "")
        let url = try makeParquet("doubles.parquet", sql: """
            SELECT 0.5::DOUBLE AS d_half, 0.05::DOUBLE AS d_005,
                   0.0000000001::DOUBLE AS d_tiny, 100.0::DOUBLE AS d_whole,
                   123.456789::DOUBLE AS d_prec, -0.25::DOUBLE AS d_neg
            """)
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url)
        XCTAssertNil(mgr.errorMessage)
        XCTAssertEqual(mgr.rows.count, 1)
        func cell(_ col: String) -> String {
            let ci = try! XCTUnwrap(mgr.columns.firstIndex(of: col))
            return mgr.rows[0][ci]
        }
        XCTAssertEqual(cell("d_half"), "0.5")
        XCTAssertEqual(cell("d_005"), "0.05")
        XCTAssertEqual(cell("d_tiny"), "1e-10")
        XCTAssertEqual(cell("d_whole"), "100.0")
        XCTAssertEqual(cell("d_prec"), "123.456789")
        XCTAssertEqual(cell("d_neg"), "-0.25")
    }

    func testMaliciousCSVHeaderDoesNotBreakLoader() async throws {
        let url = try write("evil_header.csv", "a\" ,b\n1,2\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: url, skipIntegrityCheck: true)
        // Must either load safely or report a clean error — never a crash.
        if let err = mgr.errorMessage {
            XCTAssertFalse(err.isEmpty)
        } else {
            XCTAssertEqual(mgr.rows.count, 1)
        }
    }

    // MARK: - Export round-trip

    func testExportToCSVRoundTrip() async throws {
        let src = try write("roundtrip.csv", "id,name\n1,alpha\n2,beta\n")
        let mgr = DuckDBManager()
        await mgr.loadParquet(url: src, skipIntegrityCheck: true)
        let dst = Self.fixtureDir.appendingPathComponent("export_out.csv")
        try? FileManager.default.removeItem(at: dst)
        try await mgr.exportToCSV(url: dst)
        let content = try String(contentsOf: dst, encoding: .utf8)
        XCTAssertTrue(content.contains("alpha"))
        XCTAssertTrue(content.contains("beta"))
    }
}
