#!/usr/bin/env swift

// SM-2 Validation Test - Simple DuckDB Parquet Test
// This is a standalone test script

import Foundation
import DuckDB

print("?? SM-2: DuckDB-Swift Parquet Reading Test")
print(String(repeating: "=", count: 60))

let testFile = "/Users/fl/Python/Parquet_View/sample_data.parquet"

do {
    print("\n?? Step 1: Initialize DuckDB")
    let db = try Database(store: .inMemory)
    print("? Database created (in-memory)")
    
    print("\n?? Step 2: Connect to database")
    let conn = try db.connect()
    print("? Connection established")
    
    print("\n?? Step 3: Read Parquet file")
    print("   File: \(testFile)")
    
    let escapedPath = testFile.replacingOccurrences(of: "'", with: "''")
    let query = "SELECT * FROM read_parquet('\(escapedPath)') LIMIT 10"
    
    print("\n? Executing query...")
    let result = try conn.query(query)
    
    print("\n? SUCCESS! Parquet file read successfully!")
    print(String(repeating: "=", count: 60))
    
    // Display results - using DuckDB 1.1.3 API
    print("\n?? Schema Information:")
    print("   Rows returned: \(result.count)")
    
    if result.count > 0 {
        print("\n   Sample data (first row):")
        if let firstRow = result.first {
            print("   \(firstRow)")
        }
    }
    
    print("\n" + String(repeating: "=", count: 60))
    print("?? SM-2 VALIDATION: ? PASSED!")
    print(String(repeating: "=", count: 60))
    print("\n? DuckDB-Swift CAN read Parquet files!")
    print("? Plan A is viable - Continue with Swift implementation")
    print("\n?? Next steps:")
    print("   1. ? SM-2 validated - DuckDB works")
    print("   2. ?? SM-3: Implement DuckDBManager")
    print("   3. ?? SM-5: Build SwiftUI interface")
    print("   4. ?? SM-15: Full feature testing")
    
} catch {
    print("\n? ERROR: \(error)")
    print("\n" + String(repeating: "=", count: 60))
    print("? SM-2 VALIDATION: FAILED")
    print(String(repeating: "=", count: 60))
    print("\nError details: \(error.localizedDescription)")
    print("\n??  Plan A failed - Need to activate Plan C:")
    print("   Option C1: Python bridge (PythonKit + Polars)")
    print("   Option C2: Tauri (Rust backend + web UI)")
    print("   Option C3: Hybrid (Swift UI + Rust FFI)")
    
    exit(1)
}
