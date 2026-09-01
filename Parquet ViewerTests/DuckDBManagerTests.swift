import XCTest
@testable import ParquetViewLib

@MainActor
final class DuckDBManagerTests: XCTestCase {
    var sut: DuckDBManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = DuckDBManager()
    }

    override func tearDown() async throws {
        sut = nil
        try? TestHelpers.cleanupTempDirectory()
        try await super.tearDown()
    }

    // MARK: - Fixture helpers (self-contained; no files outside the repo)

    /// 4 columns x 5 rows with the columns the filter/sort tests rely on
    private func makeSampleCSV() throws -> URL {
        try TestHelpers.createTestCSVWithCustomContent(
            filename: "sample.csv",
            headers: ["id", "name", "salary", "dept"],
            rows: [
                ["1", "Alice", "50000", "Eng"],
                ["2", "Bob", "45000", "Sales"],
                ["3", "Alice Wang", "60000", "Eng"],
                ["4", "Carol", "52000", "HR"],
                ["5", "Dave", "47000", "Sales"],
            ]
        )
    }

    private func makeLargeCSV(rows: Int = 3000) throws -> URL {
        try TestHelpers.createLargeTestCSV(rows: rows)
    }

    private func makeSmallCSV() throws -> URL {
        try TestHelpers.createTestCSV(filename: "small.csv", rows: 10)
    }

    // MARK: - Initial State Tests (Logic Only - No File Loading)

    func testInitialState() {
        XCTAssertTrue(sut.columns.isEmpty)
        XCTAssertTrue(sut.rows.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.totalRowCount, 0)
        XCTAssertEqual(sut.displayedRowCount, 0)
        XCTAssertNil(sut.fileInfo)
        XCTAssertFalse(sut.hasLoadedFile)
        XCTAssertEqual(sut.loadingProgress, 0.0)
        XCTAssertTrue(sut.columnStats.isEmpty)
        XCTAssertNil(sut.sortColumn)
        XCTAssertTrue(sut.sortAscending)
    }

    func testHasMoreData_initiallyFalse() {
        XCTAssertFalse(sut.hasMoreData)
    }

    func testDisplayProperties_initialState() {
        XCTAssertEqual(sut.displayedRowCount, 0)
        XCTAssertEqual(sut.totalRowCount, 0)
    }

    func testLoadingProgress_initiallyZero() {
        XCTAssertEqual(sut.loadingProgress, 0.0)
    }

    // MARK: - Clear Data Tests (Logic Only)

    func testClearData_resetsToInitialState() {
        sut.clearData()

        XCTAssertTrue(sut.columns.isEmpty)
        XCTAssertTrue(sut.rows.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.totalRowCount, 0)
        XCTAssertEqual(sut.displayedRowCount, 0)
        XCTAssertNil(sut.fileInfo)
        XCTAssertFalse(sut.hasLoadedFile)
        XCTAssertEqual(sut.loadingProgress, 0.0)
        XCTAssertTrue(sut.columnStats.isEmpty)
        XCTAssertNil(sut.sortColumn)
        XCTAssertTrue(sut.sortAscending)
    }

    // MARK: - Sort Logic Tests (No File Loading)

    func testToggleSort_noFile() async {
        await sut.toggleSort(for: "name")

        XCTAssertEqual(sut.sortColumn, "name")
        XCTAssertFalse(sut.hasLoadedFile)
    }

    // MARK: - LoadMoreData Tests (Logic Only)

    func testLoadMoreData_noFile() async {
        await sut.loadMoreData()

        XCTAssertEqual(sut.rows.count, 0)
        XCTAssertFalse(sut.isLoadingMore)
    }

    func testHasMoreData_logic() {
        sut.totalRowCount = 100

        // Window covers rows 0..<50 → more data
        sut.currentStartRow = 0
        sut.rows = Array(repeating: [], count: 50)
        XCTAssertTrue(sut.hasMoreData)

        // Window covers rows 0..<100 → done
        sut.rows = Array(repeating: [], count: 100)
        XCTAssertFalse(sut.hasMoreData)

        // Window extends past the end → done
        sut.rows = Array(repeating: [], count: 150)
        XCTAssertFalse(sut.hasMoreData)
    }

    // MARK: - File Loading Tests (self-generated fixtures)

    func testLoadParquet_smallFile() async throws {
        let url = try makeSampleCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)

        XCTAssertNil(sut.errorMessage, "load must succeed: \(sut.errorMessage ?? "")")
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.hasLoadedFile)
        XCTAssertEqual(sut.columns.count, 4)
        XCTAssertEqual(sut.rows.count, 5)
        XCTAssertEqual(sut.totalRowCount, 5)
    }

    func testLoadMoreData_appendsRows() async throws {
        let url = try makeLargeCSV(rows: 3000)
        await sut.loadParquet(url: url, limit: 500, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage, "load must succeed: \(sut.errorMessage ?? "")")

        XCTAssertEqual(sut.rows.count, 500)
        XCTAssertTrue(sut.hasMoreData)

        await sut.loadMoreData()
        XCTAssertEqual(sut.rows.count, 1500)
    }

    func testHasMoreData_whenMoreRowsExist() async throws {
        let url = try makeLargeCSV(rows: 3000)
        await sut.loadParquet(url: url, limit: 100, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.hasMoreData)
    }

    func testHasMoreData_whenAllRowsLoaded() async throws {
        let url = try makeSmallCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.hasMoreData)
    }

    // MARK: - Error Handling Tests

    func testLoadParquet_emptyFile() async throws {
        let testURL = try TestHelpers.createEmptyCSV()

        await sut.loadParquet(url: testURL)

        XCTAssertFalse(sut.isLoading)
        // Empty file surfaces as a CSV integrity issue for the UI to present
        XCTAssertEqual(sut.csvIssueResult?.issueType, .emptyFile)
        XCTAssertFalse(sut.hasLoadedFile)
    }

    func testLoadParquet_invalidExtension() async throws {
        let testURL = try TestHelpers.createInvalidExtensionFile()

        await sut.loadParquet(url: testURL)

        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Unsupported"))
    }

    func testLoadParquet_nonExistentFile() async {
        let testURL = URL(fileURLWithPath: "/nonexistent/path/file.csv")

        await sut.loadParquet(url: testURL)

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.hasLoadedFile)
    }

    // MARK: - Filter Tests (Logic)

    func testFilterData_noFile() async {
        await sut.filterData(searchText: "test")

        XCTAssertEqual(sut.rows.count, 0)
    }

    func testFilterData_emptyString_noFile() async {
        await sut.filterData(searchText: "")

        XCTAssertEqual(sut.rows.count, 0)
    }

    // MARK: - Clear Data After Error Tests

    func testClearData_afterLoadAttempt() async {
        let testURL = URL(fileURLWithPath: "/nonexistent/file.csv")
        await sut.loadParquet(url: testURL)

        XCTAssertNotNil(sut.errorMessage)

        sut.clearData()

        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.hasLoadedFile)
    }

    // MARK: - Integration Tests (self-generated fixtures)

    func testFilterData_withResults() async throws {
        let url = try makeSampleCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)

        await sut.filterData(searchText: "Alice")

        XCTAssertEqual(sut.rows.count, 2, "exactly Alice and Alice Wang match")
        let nameIdx = sut.columns.firstIndex(of: "name")!
        XCTAssertTrue(sut.rows.allSatisfy { $0[nameIdx].contains("Alice") })
    }

    func testFilterData_byColumn() async throws {
        let url = try makeSampleCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)

        await sut.filterData(searchText: "Alice", column: "name")

        XCTAssertGreaterThan(sut.rows.count, 0)
    }

    func testClearData_afterSuccessfulLoad() async throws {
        let url = try makeSmallCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)

        XCTAssertTrue(sut.hasLoadedFile)
        XCTAssertNotNil(sut.fileInfo)
        XCTAssertFalse(sut.columns.isEmpty)
        XCTAssertFalse(sut.rows.isEmpty)

        sut.clearData()

        XCTAssertNil(sut.fileInfo)
        XCTAssertTrue(sut.columns.isEmpty)
        XCTAssertTrue(sut.rows.isEmpty)
        XCTAssertEqual(sut.totalRowCount, 0)
        XCTAssertEqual(sut.displayedRowCount, 0)
        XCTAssertFalse(sut.hasLoadedFile)
        XCTAssertNil(sut.errorMessage)
    }

    func testSortByColumn() async throws {
        let url = try makeSampleCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)

        await sut.sortByColumn("salary", ascending: true)

        XCTAssertEqual(sut.sortColumn, "salary")
        XCTAssertTrue(sut.sortAscending)
        // Sorted for real, not just flags (salaries ascending)
        let salaryIdx = sut.columns.firstIndex(of: "salary")!
        let salaries = sut.rows.map { Double($0[salaryIdx]) ?? -1 }
        XCTAssertEqual(salaries, salaries.sorted(), "rows must actually be reordered")
    }

    func testToggleSort_afterLoad() async throws {
        let url = try makeSampleCSV()
        await sut.loadParquet(url: url, skipIntegrityCheck: true)
        XCTAssertNil(sut.errorMessage)

        await sut.toggleSort(for: "name")

        XCTAssertEqual(sut.sortColumn, "name")
        XCTAssertTrue(sut.sortAscending)

        await sut.toggleSort(for: "name")

        XCTAssertFalse(sut.sortAscending)
    }
}
