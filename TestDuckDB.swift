#!/usr/bin/env swift
// Quick test to validate DuckDB-Swift can read Parquet files
// This is SM-2: DuckDB-Swift Integration (Plan B Validation)

import Foundation

print("?? DuckDB-Swift Parquet Test")
print("=" + String(repeating: "=", count: 50))

// Test file path
let testFile = "/Users/fl/Python/Parquet_View/sample_data.parquet"
print("\n?? Test file: \(testFile)")

// Check if file exists
let fileExists = FileManager.default.fileExists(atPath: testFile)
print("? File exists: \(fileExists)")

if !fileExists {
    print("? Test file not found!")
    print("   Please ensure sample_data.parquet exists at:")
    print("   \(testFile)")
    exit(1)
}

// Get file size
if let attributes = try? FileManager.default.attributesOfItem(atPath: testFile),
   let fileSize = attributes[.size] as? UInt64 {
    let sizeMB = Double(fileSize) / 1_000_000.0
    print("? File size: \(String(format: "%.2f", sizeMB)) MB")
}

print("\n" + String(repeating: "=", count: 50))
print("?? DuckDB-Swift Package Required")
print("=" + String(repeating: "=", count: 50))
print("\nTo complete this test:")
print("1. Add DuckDB-Swift package to Xcode project")
print("2. URL: https://github.com/duckdb/duckdb-swift")
print("3. Import DuckDB in your Swift files")
print("\nThen run this code:\n")
print("""
import DuckDB

let db = try Database(store: .inMemory)
let conn = try db.connect()

let query = \"\"\"
    SELECT * FROM read_parquet('\(testFile)')
    LIMIT 10
\"\"\"

let result = try conn.query(query)
print("Columns: \\(result.columns.map { $0.name })")
print("Row count: \\(result.count)")

for (index, row) in result.enumerated() {
    print("Row \\(index): ", terminator: "")
    for (colIndex, _) in result.columns.enumerated() {
        print(row.column(colIndex), terminator: " | ")
    }
    print()
}
""")

print("\n" + String(repeating: "=", count: 50))
print("? Pre-test validation complete!")
print("   File is ready for DuckDB reading.")
print("=" + String(repeating: "=", count: 50))
