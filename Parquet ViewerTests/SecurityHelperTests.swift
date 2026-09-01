import XCTest
@testable import ParquetViewLib

final class SecurityHelperTests: XCTestCase {
    
    // MARK: - Sanitize Path Tests
    
    func testSanitizePath_validPath() {
        let path = "/Users/test/data/file.parquet"
        
        let result = SecurityHelper.sanitizePath(path)
        
        XCTAssertEqual(result, path)
    }
    
    func testSanitizePath_emptyString() {
        let result = SecurityHelper.sanitizePath("")
        
        XCTAssertNil(result)
    }
    
    func testSanitizePath_withSingleQuotes() {
        let path = "/path/with'quote/file.parquet"
        
        let result = SecurityHelper.sanitizePath(path)
        
        XCTAssertEqual(result, "/path/with''quote/file.parquet")
    }
    
    func testSanitizePath_withBackslash() {
        // Backslashes are literal characters in DuckDB standard string
        // literals — they must be preserved as-is (doubling them would make
        // DuckDB look for a path that does not exist).
        let path = "C:\\path\\to\\file.parquet"

        let result = SecurityHelper.sanitizePath(path)

        XCTAssertEqual(result, "C:\\path\\to\\file.parquet")
    }
    
    func testSanitizePath_sqlInjection() {
        let maliciousPaths = [
            "/path/file'; DROP TABLE users; --.parquet",
            "/path/file' OR '1'='1.parquet",
            "/path/file\"); DELETE FROM data; --.parquet"
        ]
        
        for path in maliciousPaths {
            let result = SecurityHelper.sanitizePath(path)
            if let sanitized = result {
                XCTAssertFalse(sanitized.contains("'") && !sanitized.contains("''"))
            }
        }
    }
    
    // MARK: - Path Traversal Tests
    
    func testSanitizePath_pathTraversal_relative() {
        let path = "/path/../../../etc/passwd"
        
        let result = SecurityHelper.sanitizePath(path)
        
        XCTAssertNil(result)
    }
    
    func testSanitizePath_pathTraversal_inMiddle() {
        let path = "/valid/path/../../secret/file.parquet"
        
        let result = SecurityHelper.sanitizePath(path)
        
        XCTAssertNil(result)
    }
    
    // MARK: - Validate File Path Tests
    
    func testValidateFilePath_validPath() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_valid.parquet")
        
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = SecurityHelper.validateFilePath(testFile)
        
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
        
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testValidateFilePath_fileNotFound() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/file.parquet")
        
        let result = SecurityHelper.validateFilePath(nonExistentURL)
        
        switch result {
        case .success:
            XCTFail("Expected failure for non-existent file")
        case .failure(let error):
            if case .fileNotFound = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected fileNotFound error")
            }
        }
    }
    
    func testValidateFilePath_invalidExtension() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_invalid.txt")
        
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = SecurityHelper.validateFilePath(testFile)
        
        switch result {
        case .success:
            XCTFail("Expected failure for unsupported file type")
        case .failure(let error):
            if case .unsupportedFileType = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected unsupportedFileType error")
            }
        }
        
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testValidateFilePath_parquetExtension() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.parquet")
        
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = SecurityHelper.validateFilePath(testFile)
        
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Expected success for parquet file")
        }
        
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testValidateFilePath_csvExtension() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.csv")
        
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = SecurityHelper.validateFilePath(testFile)
        
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Expected success for CSV file")
        }
        
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testValidateFilePath_pathTraversal() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("../test.parquet")
        
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = SecurityHelper.validateFilePath(testFile)
        
        switch result {
        case .success:
            XCTFail("Expected failure for path traversal")
        case .failure(let error):
            if case .pathTraversal = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected pathTraversal error")
            }
        }
        
        try? FileManager.default.removeItem(at: testFile)
    }
}

final class SecurityErrorTests: XCTestCase {
    
    func testSecurityError_fileNotFound() {
        let error = SecurityError.fileNotFound(path: "/test/path")
        
        XCTAssertEqual(error.errorDescription, "File not found: /test/path")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testSecurityError_fileNotReadable() {
        let error = SecurityError.fileNotReadable(path: "/test/path")
        
        XCTAssertEqual(error.errorDescription, "Cannot read file: /test/path")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testSecurityError_unsupportedFileType() {
        let error = SecurityError.unsupportedFileType(extension: "txt")
        
        XCTAssertTrue(error.errorDescription!.contains("Unsupported file type: .txt"))
        XCTAssertTrue(error.errorDescription!.contains("parquet, csv"))
    }
    
    func testSecurityError_pathTraversal() {
        let error = SecurityError.pathTraversal
        
        XCTAssertEqual(error.errorDescription, "Invalid file path: Path traversal detected")
    }
    
    func testSecurityError_accessDenied() {
        let error = SecurityError.accessDenied(path: "/test/path")
        
        XCTAssertEqual(error.errorDescription, "Access denied: /test/path")
    }
    
    func testSecurityError_sqlInjectionAttempt() {
        let error = SecurityError.sqlInjectionAttempt
        
        XCTAssertEqual(error.errorDescription, "Security error: Invalid characters in query")
    }
}
