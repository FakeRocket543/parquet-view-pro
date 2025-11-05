# Quick Start Guide - Parquet View Swift

## ?? TL;DR - Get Running in 5 Minutes

```bash
# 1. Run the setup script
/Users/fl/Desktop/ParquetViewerSwift/start_xcode.sh

# 2. In Xcode:
#    - File ? New ? Project ? macOS App
#    - Name: "Parquet View"
#    - Interface: SwiftUI
#    - Save to: /Users/fl/Desktop/ParquetViewerSwift

# 3. Add DuckDB package:
#    - Project ? Package Dependencies ? +
#    - URL: https://github.com/duckdb/duckdb-swift

# 4. Build and run:
#    - Cmd+R

# 5. Test:
#    - Open /Users/fl/Python/Parquet_View/sample_data.parquet
```

## ?? Project Files

### Core Code (5 files, 960 lines)
```
Parquet View/
??? ParquetViewerApp.swift    # App entry (29 lines)
??? DuckDBManager.swift        # Data logic (274 lines)
??? ContentView.swift          # Main UI (393 lines)
??? DataTableView.swift        # Table view (133 lines)
??? SettingsView.swift         # Settings (111 lines)
```

### Documentation (4 files)
```
??? README.md                  # Project overview
??? BUILD_INSTRUCTIONS.md      # Detailed guide
??? MIGRATION_STATUS.md        # Progress tracker
??? HANDOVER_REPORT.md         # Complete summary
```

## ? What's Done

- ? All Swift code written
- ? DuckDB integration ready
- ? File associations configured
- ? UI fully implemented
- ? Documentation complete

## ? What You Need To Do

1. **Build in Xcode** (30 min)
2. **Test DuckDB** (10 min) ?? **CRITICAL**
3. **Try opening files** (10 min)
4. **Report results**

## ?? Quick Commands

```bash
# Open project folder
open /Users/fl/Desktop/ParquetViewerSwift

# View all Swift files
ls -lh "Parquet View/"*.swift

# Count lines of code
find . -name "*.swift" -exec wc -l {} + | tail -1

# Copy test file
cp /Users/fl/Python/Parquet_View/sample_data.parquet ~/Desktop/test.parquet

# Open Xcode
open -a Xcode
```

## ??  Critical Test (SM-2)

**After building, you MUST test if DuckDB can read Parquet files:**

```swift
import DuckDB

let db = try Database(store: .inMemory)
let conn = try db.connect()
let result = try conn.query(
    "SELECT * FROM read_parquet('~/Desktop/test.parquet') LIMIT 10"
)
print("? Works! Rows:", result.count)
```

**If this fails**: 
- Report the error
- We'll implement Plan C (Python bridge or Tauri)

## ?? Progress

```
Code:    100% ?
Docs:    100% ?
Testing:   0% ?  ? YOU ARE HERE
Release:   0% ?
```

## ?? Success Looks Like

? App builds without errors  
? App launches  
? Can open Parquet files  
? Data displays in table  
? Double-click works  

## ?? Need More Details?

- **Building**: `BUILD_INSTRUCTIONS.md`
- **Status**: `MIGRATION_STATUS.md`
- **Context**: `HANDOVER_REPORT.md`
- **Usage**: `README.md`

## ?? Troubleshooting

### "Cannot find 'Database' in scope"
? Add DuckDB package in Xcode

### "App crashes on launch"
? Check Console.app for errors

### "Can't open Parquet files"
? Run SM-2 validation test

### "Build errors"
? Product ? Clean Build Folder (Cmd+Shift+K)

## ?? Ready?

**Run this command to start:**

```bash
/Users/fl/Desktop/ParquetViewerSwift/start_xcode.sh
```

Then follow the prompts!

---

**Questions?** Check `HANDOVER_REPORT.md` for complete details.

**Good luck! ??**
