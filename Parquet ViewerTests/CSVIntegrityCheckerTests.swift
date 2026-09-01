import XCTest
@testable import ParquetViewLib

final class CSVIntegrityCheckerTests: XCTestCase {

    override func tearDown() {
        try? TestHelpers.cleanupTempDirectory()
        super.tearDown()
    }

    // MARK: - Valid CSV

    func testValidCSV() throws {
        let url = try TestHelpers.createTestCSV(rows: 5)
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.issueType)
    }

    // MARK: - Empty / Missing

    func testEmptyFile() throws {
        let url = try TestHelpers.createEmptyCSV()
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .emptyFile)
    }

    func testNonExistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/file.csv")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .emptyFile)
    }

    // MARK: - Truncated Last Row

    func testTruncatedLastRow() throws {
        let url = try writeTempCSV("truncated.csv",
            "a,b,c\n1,2,3\n4,5")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .truncatedLastRow)
        XCTAssertTrue(result.suggestedActions.contains(.skipLastRow))
    }

    // MARK: - Mismatched Columns

    func testMismatchedColumns_middleRow() throws {
        let url = try writeTempCSV("mismatch.csv",
            "a,b,c\n1,2,3\n4,5\n7,8,9")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .mismatchedColumns)
    }

    // MARK: - Unmatched Quotes

    func testUnmatchedQuotes() throws {
        let url = try writeTempCSV("quotes.csv",
            "a,b\n1,\"hello\n2,world")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .unmatchedQuotes)
    }

    // MARK: - Quoted Fields (Valid)

    func testValidQuotedFields() throws {
        let url = try writeTempCSV("quoted.csv",
            "a,b\n1,\"hello, world\"\n2,\"ok\"")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - createTruncatedContent

    func testCreateTruncatedContent() throws {
        // check() reports the number of valid physical records (header
        // included); createTruncatedContent must keep exactly that many
        // records and drop the truncated tail.
        let url = try writeTempCSV("trunc.csv",
            "a,b\n1,2\n3,4\n5")
        let result = CSVIntegrityChecker.check(url: url)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issueType, .truncatedLastRow)

        let content = CSVIntegrityChecker.createTruncatedContent(from: url, upToRow: result.lastValidRowIndex)
        XCTAssertNotNil(content)
        let records = CSVIntegrityChecker.parseRecords(in: content!)
        XCTAssertEqual(records.count, 3) // header + 2 intact data rows
        XCTAssertEqual(records.last, "3,4")
    }

    // MARK: - Helper

    private func writeTempCSV(_ name: String, _ content: String) throws -> URL {
        try TestHelpers.setupTempDirectory()
        let url = TestHelpers.tempDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
