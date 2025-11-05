# CSV Support Fix Documentation

## Issue Summary

CSV files could not be loaded, resulting in DuckDB error 4: "The operation couldn't be completed."

---

## Root Cause

### Problem 1: Incorrect SQL Syntax for CSV Reading

**Initial Implementation (Broken):**
```swift
case "csv":
    readFunction = "read_csv_auto"
    readOptions = ", AUTO_DETECT=TRUE"

let countQuery = "SELECT COUNT(*) as count FROM \(readFunction)('\(path)'\(readOptions))"
// Result: "SELECT COUNT(*) as count FROM read_csv_auto('/path/to/file.csv', AUTO_DETECT=TRUE)"
// ? Syntax error! Trailing comma and incorrect parameter format
```

**Why This Failed:**
- The `, AUTO_DETECT=TRUE` creates invalid SQL syntax
- DuckDB's `read_csv_auto()` doesn't accept parameters this way
- The function auto-detects by default

### Problem 2: Export Function Using Wrong CSV Reader

**Export Implementation (Broken):**
```swift
let readFunction = (fileExtension == "csv") ? "read_csv" : "read_parquet"
// Uses read_csv instead of read_csv_auto
```

**Why This Failed:**
- `read_csv()` requires explicit parameters
- `read_csv_auto()` is the correct function for automatic detection

---

## Solution

### Fix 1: Correct CSV Reading Syntax

**Corrected Implementation:**
```swift
switch fileExtension {
case "csv":
    // CSV: Use read_csv_auto with proper syntax
    countQuery = "SELECT COUNT(*) as count FROM read_csv_auto('\(path)')"
    dataQuery = """
        SELECT * FROM read_csv_auto('\(path)')
        LIMIT \(rowLimit) OFFSET \(startOffset)
    """
case "parquet":
    // Parquet: Use read_parquet
    countQuery = "SELECT COUNT(*) as count FROM read_parquet('\(path)')"
    dataQuery = """
        SELECT * FROM read_parquet('\(path)')
        LIMIT \(rowLimit) OFFSET \(startOffset)
    """
}
```

**Key Changes:**
- ? Build complete SQL queries upfront
- ? Use `read_csv_auto()` without extra parameters
- ? Function auto-detects delimiter, quotes, headers
- ? Separate query construction for clarity

### Fix 2: Correct Export Function

**Corrected Export:**
```swift
// Determine source file type and build read query
let fileExtension = fileURL.pathExtension.lowercased()
let readQuery: String
switch fileExtension {
case "csv":
    readQuery = "SELECT * FROM read_csv_auto('\(sourcePath)')"
case "parquet":
    readQuery = "SELECT * FROM read_parquet('\(sourcePath)')"
default:
    readQuery = "SELECT * FROM read_parquet('\(sourcePath)')"
}

// Build export query based on format
let exportQuery: String
switch format {
case .csv:
    exportQuery = """
        COPY (\(readQuery))
        TO '\(destPath)' (HEADER, DELIMITER ',')
    """
case .parquet:
    exportQuery = """
        COPY (\(readQuery))
        TO '\(destPath)' (FORMAT 'parquet')
    """
}
```

**Key Changes:**
- ? Use `read_csv_auto()` for source CSV files
- ? Consistent query building pattern
- ? Proper COPY syntax for both formats

---

## DuckDB CSV Functions Reference

### `read_csv_auto(filename)`
**Purpose:** Automatically detect CSV format and read file

**Auto-Detects:**
- Delimiter (comma, semicolon, tab, pipe, etc.)
- Quote character (single or double quotes)
- Header presence
- Encoding
- Data types

**Usage:**
```sql
-- ? Correct - auto-detection
SELECT * FROM read_csv_auto('data.csv')

-- ? Wrong - no parameters needed
SELECT * FROM read_csv_auto('data.csv', AUTO_DETECT=TRUE)
```

### `read_csv(filename, options...)`
**Purpose:** Read CSV with explicit parameters

**Requires:**
- Manual specification of delimiter
- Manual specification of quote character
- Manual specification of header
- Manual specification of types

**Usage:**
```sql
-- Requires explicit parameters
SELECT * FROM read_csv('data.csv', 
    delimiter=',', 
    header=true,
    quote='"'
)
```

**When to Use:**
- `read_csv_auto()`: Default choice (95% of cases)
- `read_csv()`: Only when auto-detection fails or you need precise control

---

## Testing CSV Support

### Test Case 1: Basic CSV
```csv
name,age,city
Alice,30,NYC
Bob,25,LA
```

**Expected:** Load successfully with 2 rows, 3 columns

### Test Case 2: CSV with Different Delimiter
```csv
name;age;city
Alice;30;NYC
Bob;25;LA
```

**Expected:** Auto-detect semicolon delimiter, load successfully

### Test Case 3: CSV with Quotes
```csv
name,description,price
"Widget A","High quality, durable",29.99
"Widget B","Compact, portable",19.99
```

**Expected:** Handle quoted fields with commas correctly

### Test Case 4: CSV without Headers
```csv
Alice,30,NYC
Bob,25,LA
```

**Expected:** Auto-detect no header, generate column names (column0, column1, column2)

---

## Export Testing

### CSV to CSV
1. Load CSV file
2. Export as CSV
3. Verify output has headers
4. Verify data matches

### CSV to Parquet
1. Load CSV file
2. Export as Parquet
3. Reload exported Parquet
4. Verify data matches

### Parquet to CSV
1. Load Parquet file
2. Export as CSV
3. Verify output has headers
4. Verify data matches

### Parquet to Parquet
1. Load Parquet file
2. Export as Parquet
3. Reload exported Parquet
4. Verify data matches

---

## Common CSV Issues and Solutions

### Issue: "Invalid CSV format"
**Solution:** File might not be CSV. Check file extension and content.

### Issue: "Encoding error"
**Solution:** `read_csv_auto()` handles most encodings. If fails, file might be corrupted.

### Issue: "Wrong number of columns"
**Solution:** CSV might have inconsistent row lengths. Check for malformed rows.

### Issue: "Date parsing fails"
**Solution:** DuckDB auto-detects dates. If fails, dates might be in unusual format.

---

## Implementation Details

### Files Modified
- `DuckDBManager.swift`: 
  - `loadParquet()` function (handles both CSV and Parquet)
  - `exportData()` function (export to both formats)

### Code Locations
```swift
// DuckDBManager.swift, line ~95
switch fileExtension {
case "csv":
    countQuery = "SELECT COUNT(*) as count FROM read_csv_auto('\(path)')"
    dataQuery = """
        SELECT * FROM read_csv_auto('\(path)')
        LIMIT \(rowLimit) OFFSET \(startOffset)
    """
```

```swift
// DuckDBManager.swift, line ~235
switch fileExtension {
case "csv":
    readQuery = "SELECT * FROM read_csv_auto('\(sourcePath)')"
case "parquet":
    readQuery = "SELECT * FROM read_parquet('\(sourcePath)')"
}
```

---

## Performance Notes

### CSV vs Parquet
| Feature | CSV | Parquet |
|---------|-----|---------|
| **Load Speed** | Slower | Faster |
| **File Size** | Larger | Smaller |
| **Compression** | None/Minimal | High |
| **Compatibility** | Universal | Requires special tools |
| **Human Readable** | Yes | No |

### Recommendations
- **For large datasets**: Use Parquet
- **For sharing**: Use CSV (more compatible)
- **For archiving**: Use Parquet (smaller size)
- **For editing**: Use CSV (can open in Excel/text editor)

---

## Future Enhancements

### Possible Improvements
1. **Custom CSV options dialog**
   - Let users override auto-detection
   - Specify delimiter, quote char, encoding

2. **Preview before import**
   - Show first few rows
   - Confirm column detection

3. **Error details**
   - Show which row failed
   - Suggest fixes for common issues

4. **Batch conversion**
   - Convert multiple files at once
   - Folder-level operations

---

## Conclusion

CSV support is now fully functional using DuckDB's `read_csv_auto()` function. This provides robust auto-detection of CSV formats while maintaining simplicity in the codebase.

**Key Learnings:**
- Always use `read_csv_auto()` for CSV files
- Don't add extra parameters unless needed
- Build complete SQL queries for clarity
- Test export functions with all format combinations

---

## References

- DuckDB CSV Documentation: https://duckdb.org/docs/data/csv
- DuckDB-Swift API: https://github.com/duckdb/duckdb-swift
- Test files location: `~/Desktop/ParquetViewerSwift/test_sample.csv`

**Document Version:** 1.0  
**Last Updated:** 2025-11-05  
**Author:** Swift Migration Team
