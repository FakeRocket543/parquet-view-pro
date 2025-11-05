#!/usr/bin/env swift
// SM-2 Validation Test - Fixed for DuckDB-Swift 1.1.3 API

import Foundation
import DuckDB

print("?? SM-2: DuckDB-Swift Parquet Reading Test (API v1.1.3)")
print(String(repeating: "=", count: 70))

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
    
    // Escape single quotes in path
    let escapedPath = testFile.replacingOccurrences(of: "'", with: "''")
    
    // Try to read the Parquet file
    let query = "SELECT * FROM read_parquet('\(escapedPath)') LIMIT 10"
    
    print("\n? Executing query...")
    let result = try conn.query(query)
    
    print("\n? SUCCESS! Parquet file read successfully!")
    print(String(repeating: "=", count: 70))
    
    // Display results using DuckDB 1.1.3 API
    print("\n?? Schema Information:")
    print("   Columns: \(result.columnCount)")
    print("   Rows returned: \(result.rowCount)")
    
    // Print column names
    print("\n   Column names:")
    for i in 0..<result.columnCount {
        let columnName = result.columnName(at: i)
        print("     [\(i)] \(columnName)")
    }
    
    // Print first few rows (simplified)
    if result.rowCount > 0 {
        print("\n   Sample data (first 3 rows):")
        for rowIndex in 0..<min(3, result.rowCount) {
            print("   Row \(rowIndex + 1):")
            for colIndex in 0..<result.columnCount {
                let columnName = result.columnName(at: colIndex)
                let column = result.column(at: colIndex)
                
                // Try to cast to string for display
                if let stringColumn = try? column.cast(to: String.self) {
                    let value = stringColumn[Int(rowIndex)]
                    print("     \(columnName): \(value ?? "NULL")")
                } else {
                    print("     \(columnName): <not string>")
                }
            }
        }
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("?? SM-2 VALIDATION: ? PASSED!")
    print(String(repeating: "=", count: 70))
    print("\n? DuckDB-Swift CAN read Parquet files!")
    print("? Plan A is viable - Continue with Swift implementation")
    print("\n?? Next steps:")
    print("   1. ? SM-2 validated - DuckDB works")
    print("   2. ?? SM-3: Fix DuckDBManager.swift with correct API")
    print("   3. ?? SM-5: Build SwiftUI interface")
    print("   4. ?? SM-15: Full feature testing")
    
} catch {
    print("\n? ERROR: \(error)")
    print("\n" + String(repeating: "=", count: 70))
    print("? SM-2 VALIDATION: FAILED")
    print(String(repeating: "=", count: 70))
    print("\nError details: \(error.localizedDescription)")
    print("\n??  Plan A failed - Need to activate Plan C:")
    print("   Option C1: Python bridge (PythonKit + Polars)")
    print("   Option C2: Tauri (Rust backend + web UI)")
    print("   Option C3: Hybrid (Swift UI + Rust FFI)")
    
    exit(1)
}
