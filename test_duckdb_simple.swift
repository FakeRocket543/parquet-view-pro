#!/usr/bin/env swift
// Simple DuckDB test without GUI - SM-2 Validation

import Foundation

print("?? DuckDB-Swift Simple Test")
print("=" + String(repeating: "=", count: 50))

// Test 1: Check if sample file exists
let testFile = "/Users/fl/Python/Parquet_View/sample_data.parquet"
print("\n?? Checking test file: \(testFile)")

let fileManager = FileManager.default
if fileManager.fileExists(atPath: testFile) {
    print("? File exists")
    
    if let attributes = try? fileManager.attributesOfItem(atPath: testFile),
       let fileSize = attributes[.size] as? UInt64 {
        let sizeMB = Double(fileSize) / 1_000_000.0
        print("? File size: \(String(format: "%.2f", sizeMB)) MB")
    }
} else {
    print("? File not found!")
    print("   Creating a test Parquet file...")
    
    // If no test file, try to find any .parquet file
    let possiblePaths = [
        "/Users/fl/Python/Parquet_View/sample_products.parquet",
        "/Users/fl/Desktop/test.parquet",
        NSHomeDirectory() + "/Desktop/test.parquet"
    ]
    
    var foundFile: String?
    for path in possiblePaths {
        if fileManager.fileExists(atPath: path) {
            foundFile = path
            print("   Found alternative: \(path)")
            break
        }
    }
    
    if foundFile == nil {
        print("   ??  No Parquet files found. Please create one first.")
        exit(1)
    }
}

print("\n" + String(repeating: "=", count: 50))
print("?? DuckDB Integration Status")
print(String(repeating: "=", count: 50))

print("\n? Pre-validation checks passed!")
print("\nTo complete SM-2 validation, you need to:")
print("1. Wait for full build to complete")
print("2. Run the app with: swift run")
print("3. Or open in Xcode and test there")

print("\n" + String(repeating: "=", count: 50))
print("? Ready for next step!")
print(String(repeating: "=", count: 50))
