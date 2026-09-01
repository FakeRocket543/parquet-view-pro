import XCTest
@testable import ParquetViewLib

@MainActor
final class TabManagerTests: XCTestCase {
    var sut: TabManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = TabManager()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Add Tab Tests
    
    func testAddTab_increasesCount() async throws {
        XCTAssertEqual(sut.tabs.count, 0)
        
        let result = sut.addTab(fileURL: nil)
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertNotNil(sut.selectedTabID)
    }
    
    func testAddTab_setsSelectedTabID() async throws {
        let result = sut.addTab(fileURL: nil)
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.selectedTabID, sut.tabs.first?.id)
    }
    
    func testReloadSettingsPicksUpMaxTabs() {
        UserDefaults.standard.set(3, forKey: "maxTabs")
        defer { UserDefaults.standard.removeObject(forKey: "maxTabs") }

        let tm = TabManager()
        XCTAssertEqual(tm.maxTabs, 3, "stored value must win at init")

        UserDefaults.standard.set(7, forKey: "maxTabs")
        XCTAssertEqual(tm.maxTabs, 3, "@AppStorage-in-ObservableObject never refreshes — by design")
        tm.reloadSettings()
        XCTAssertEqual(tm.maxTabs, 7, "reloadSettings must re-read the default")

        UserDefaults.standard.removeObject(forKey: "maxTabs")
        tm.reloadSettings()
        XCTAssertEqual(tm.maxTabs, DefaultSettings.maxTabCount, "no stored value → default")
    }

    func testAddEmptyTab() async throws {
        let result = sut.addEmptyTab()
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertNil(sut.tabs.first?.fileURL)
        XCTAssertEqual(sut.tabs.first?.displayName, "tab.untitled".localized)
    }
    
    func testAddTab_withFileURL() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/test.parquet")
        
        let result = sut.addTab(fileURL: testURL)
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.tabs.first?.fileURL, testURL)
        XCTAssertEqual(sut.tabs.first?.displayName, "test.parquet")
    }
    
    // MARK: - Tab Limit Tests
    
    func testAddTab_limitReached() async throws {
        sut.maxTabs = 3
        
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        XCTAssertEqual(sut.tabs.count, 3)
        XCTAssertFalse(sut.canAddTab)
        
        let result = sut.addTab(fileURL: nil)
        
        XCTAssertFalse(result)
        XCTAssertEqual(sut.tabs.count, 3)
    }
    
    func testCanAddTab_whenUnderLimit() async throws {
        sut.maxTabs = 5
        
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        XCTAssertTrue(sut.canAddTab)
    }
    
    // MARK: - Close Tab Tests
    
    func testCloseTab_decreasesCount() async throws {
        _ = sut.addTab(fileURL: nil)
        let tabID = sut.tabs.first!.id
        
        sut.closeTab(id: tabID)
        
        XCTAssertEqual(sut.tabs.count, 0)
        XCTAssertNil(sut.selectedTabID)
    }
    
    func testCloseTab_selectsAdjacentTab() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let firstTabID = sut.tabs[0].id
        let secondTabID = sut.tabs[1].id
        
        sut.selectTab(id: firstTabID)
        sut.closeTab(id: firstTabID)
        
        XCTAssertEqual(sut.selectedTabID, secondTabID)
    }
    
    func testCloseTab_selectsPreviousWhenClosingLast() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let firstTabID = sut.tabs[0].id
        let lastTabID = sut.tabs[1].id
        
        sut.selectTab(id: lastTabID)
        sut.closeTab(id: lastTabID)
        
        XCTAssertEqual(sut.selectedTabID, firstTabID)
    }
    
    func testCloseAllTabs() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        sut.closeAllTabs()
        
        XCTAssertEqual(sut.tabs.count, 0)
        XCTAssertNil(sut.selectedTabID)
    }
    
    // MARK: - Close Other Tabs Tests
    
    func testCloseOtherTabs() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let middleTabID = sut.tabs[1].id
        
        sut.closeOtherTabs(except: middleTabID)
        
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.selectedTabID, middleTabID)
    }
    
    // MARK: - Switch Tab Tests
    
    func testSwitchTab_selectedTabID() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let firstTabID = sut.tabs[0].id
        let secondTabID = sut.tabs[1].id
        
        sut.selectTab(id: firstTabID)
        XCTAssertEqual(sut.selectedTabID, firstTabID)
        
        sut.selectTab(id: secondTabID)
        XCTAssertEqual(sut.selectedTabID, secondTabID)
    }
    
    func testSelectNextTab() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let firstTabID = sut.tabs[0].id
        let secondTabID = sut.tabs[1].id
        let thirdTabID = sut.tabs[2].id
        
        sut.selectTab(id: firstTabID)
        sut.selectNextTab()
        
        XCTAssertEqual(sut.selectedTabID, secondTabID)
        
        sut.selectNextTab()
        XCTAssertEqual(sut.selectedTabID, thirdTabID)
        
        sut.selectNextTab()
        XCTAssertEqual(sut.selectedTabID, firstTabID)
    }
    
    func testSelectPreviousTab() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let firstTabID = sut.tabs[0].id
        let secondTabID = sut.tabs[1].id
        
        sut.selectTab(id: secondTabID)
        sut.selectPreviousTab()
        
        XCTAssertEqual(sut.selectedTabID, firstTabID)
        
        sut.selectPreviousTab()
        XCTAssertEqual(sut.selectedTabID, sut.tabs[2].id)
    }
    
    // MARK: - Duplicate File Tests
    
    func testAddTab_duplicateFile() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/test.parquet")
        
        _ = sut.addTab(fileURL: testURL)
        XCTAssertEqual(sut.tabs.count, 1)
        
        let result = sut.addTab(fileURL: testURL)
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tabs.count, 1)
    }
    
    func testAddTab_duplicateFile_selectsExisting() async throws {
        let testURL1 = URL(fileURLWithPath: "/tmp/test1.parquet")
        let testURL2 = URL(fileURLWithPath: "/tmp/test2.parquet")
        
        _ = sut.addTab(fileURL: testURL1)
        _ = sut.addTab(fileURL: testURL2)
        
        sut.selectTab(id: sut.tabs[1].id)
        
        _ = sut.addTab(fileURL: testURL1)
        
        XCTAssertEqual(sut.selectedTabID, sut.tabs[0].id)
    }
    
    // MARK: - Current Tab Tests
    
    func testCurrentTab_returnsNilWhenNoTabs() async throws {
        XCTAssertNil(sut.currentTab)
    }
    
    func testCurrentTab_returnsSelectedTab() async throws {
        _ = sut.addTab(fileURL: nil)
        _ = sut.addTab(fileURL: nil)
        
        let secondTabID = sut.tabs[1].id
        sut.selectTab(id: secondTabID)
        
        XCTAssertEqual(sut.currentTab?.id, secondTabID)
    }
    
    func testCurrentDBManager_returnsCorrectManager() async throws {
        _ = sut.addTab(fileURL: nil)
        
        XCTAssertNotNil(sut.currentDBManager)
        XCTAssertNotNil(sut.tabs.first?.dbManager)
    }
    
    // MARK: - Update Current Tab Tests
    
    func testUpdateCurrentTab() async throws {
        _ = sut.addEmptyTab()
        
        let testURL = URL(fileURLWithPath: "/tmp/updated.parquet")
        let result = sut.updateCurrentTab(fileURL: testURL)
        
        XCTAssertTrue(result)
        XCTAssertEqual(sut.currentTab?.fileURL, testURL)
        XCTAssertEqual(sut.currentTab?.displayName, "updated.parquet")
    }
    
    func testUpdateCurrentTab_duplicateFile_selectsExisting() async throws {
        let testURL1 = URL(fileURLWithPath: "/tmp/test1.parquet")
        let testURL2 = URL(fileURLWithPath: "/tmp/test2.parquet")
        
        _ = sut.addTab(fileURL: testURL1)
        _ = sut.addTab(fileURL: testURL2)
        
        sut.selectTab(id: sut.tabs[1].id)
        
        _ = sut.updateCurrentTab(fileURL: testURL1)
        
        XCTAssertEqual(sut.selectedTabID, sut.tabs[0].id)
    }
}
