#!/usr/bin/env swift
// ???? DuckDB Parquet ????? GUI?

import Foundation
import DuckDB

print("?? Testing DuckDB Parquet Reading...")
print("=====================================\n")

do {
    // ?? DuckDB ??
    let db = try Database(store: .inMemory)
    let conn = try db.connect()
    
    // ??????
    let testFile = "/Users/fl/Python/Parquet_View/sample_data.parquet"
    
    print("?? Loading file: \(testFile)")
    
    // ?? Parquet ??
    let query = "SELECT * FROM '\(testFile)' LIMIT 10"
    let result = try conn.query(query)
    
    print("? File loaded successfully!\n")
    
    // ????
    print("?? Columns:")
    for i in 0..<result.columnCount {
        let colName = result.columnName(at: i)
        print("  \(i + 1). \(colName)")
    }
    
    print("\n?? Data (first 10 rows):")
    print(String(repeating: "-", count: 60))
    
    // ????
    for rowIndex in 0..<min(result.rowCount, 10) {
        var rowData: [String] = []
        for colIndex in 0..<result.columnCount {
            let column = result.column(at: colIndex)
            let dbIndex = DBInt(rowIndex)
            
            // ???????
            if let stringCol = column.cast(to: String.self),
               let val = stringCol[dbIndex] {
                rowData.append(val)
            } else if let intCol = column.cast(to: Int64.self),
                      let val = intCol[dbIndex] {
                rowData.append(String(val))
            } else if let doubleCol = column.cast(to: Double.self),
                      let val = doubleCol[dbIndex] {
                rowData.append(String(format: "%.2f", val))
            } else {
                rowData.append("NULL")
            }
        }
        print("Row \(rowIndex + 1): \(rowData.joined(separator: " | "))")
    }
    
    print("\n? SUCCESS! DuckDB can read Parquet files!")
    print("\n?? Summary:")
    print("  - Columns: \(result.columnCount)")
    print("  - Rows: \(result.rowCount)")
    
} catch {
    print("? ERROR: \(error)")
    print("\n?? FAILED! DuckDB cannot read Parquet files.")
    exit(1)
}
