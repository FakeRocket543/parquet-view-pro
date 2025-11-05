// Real DuckDB Test with actual Parquet reading
// This requires the DuckDB package to be built

import Foundation
import DuckDB

print("?? DuckDB-Swift Parquet Reading Test (SM-2)")
print("=" + String(repeating: "=", count: 60))

// Test configuration
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
    let query = """
        SELECT * FROM read_parquet('\(escapedPath)')
        LIMIT 10
    """
    
    print("   Query: \(query)")
    print("\n? Executing query...")
    
    let result = try conn.query(query)
    
    print("\n? SUCCESS! Parquet file read successfully!")
    print(String(repeating: "=", count: 60))
    
    // Display results
    print("\n?? Schema Information:")
    print("   Columns: \(result.columns.count)")
    for column in result.columns {
        print("     - \(column.name)")
    }
    
    print("\n?? Data Preview (first 10 rows):")
    print("   Rows returned: \(result.count)")
    
    if result.count > 0 {
        print("\n   Sample data:")
        for (index, row) in result.enumerated().prefix(3) {
            print("   Row \(index + 1):")
            for (colIndex, column) in result.columns.enumerated() {
                let value = row.column(colIndex)
                print("     \(column.name): \(value)")
            }
        }
    }
    
    print("\n" + String(repeating: "=", count: 60))
    print("?? SM-2 VALIDATION: ? PASSED!")
    print(String(repeating: "=", count: 60))
    print("\n? DuckDB-Swift CAN read Parquet files!")
    print("? Plan A is viable - Continue with Swift implementation")
    print("\n?? Next steps:")
    print("   1. ? SM-2 validated - DuckDB works")
    print("   2. ? SM-15: Full feature testing")
    print("   3. ? SM-16: Add app icon")
    print("   4. ? SM-17: Code signing")
    print("   5. ? SM-20: Release")
    
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
