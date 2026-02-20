import Foundation
@testable import ParquetViewLib

enum TestHelpers {
    static var tempDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ParquetViewerTests")
    }
    
    static func setupTempDirectory() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    static func cleanupTempDirectory() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    static func createTestCSV(filename: String = "test.csv", rows: Int = 10) throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent(filename)
        
        var content = "id,name,value,description\n"
        for i in 1...rows {
            content += "\(i),Item\(i),\(Double(i) * 1.5),Description for item \(i)\n"
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createTestCSVWithCustomContent(filename: String, headers: [String], rows: [[String]]) throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent(filename)
        
        var content = headers.joined(separator: ",") + "\n"
        for row in rows {
            let escapedRow = row.map { field -> String in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return field
            }
            content += escapedRow.joined(separator: ",") + "\n"
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createTestCSVWithSpecialChars() throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent("special_chars.csv")
        
        var content = "id,text,value\n"
        content += "1,\"Hello, World\",100\n"
        content += "2,\"Quote \"\"test\"\"\",200\n"
        content += "3,\"Line\nBreak\",300\n"
        content += "4,Normal,400\n"
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createEmptyCSV(filename: String = "empty.csv") throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent(filename)
        try "".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createInvalidExtensionFile() throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent("test.txt")
        try "This is not a parquet file".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createTestCSVWithSQLInjection(filename: String = "injection.csv") throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent(filename)
        
        var content = "id,name,query\n"
        content += "1,Normal,SELECT * FROM table\n"
        content += "2,Injection,\"'; DROP TABLE users; --\"\n"
        content += "3,Mixed,\"value' OR '1'='1\"\n"
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func createLargeTestCSV(rows: Int = 5000) throws -> URL {
        try setupTempDirectory()
        let url = tempDirectory.appendingPathComponent("large_test.csv")
        
        var content = "id,col_a,col_b,col_c,col_d\n"
        for i in 1...rows {
            content += "\(i),ValueA\(i),ValueB\(i),ValueC\(i),ValueD\(i)\n"
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
