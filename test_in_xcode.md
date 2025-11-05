# 在 Xcode 中測試 SM-2

由於命令行編譯需要複雜的路徑配置，最簡單的方法是在 Xcode 中測試。

## 方法 1: 臨時修改 ParquetViewApp.swift（推薦）

1. 在 Xcode 中打開 `ParquetViewApp.swift`

2. 在文件**開頭**添加測試代碼：

```swift
import DuckDB

// SM-2 Test Code - Remove after validation
func testDuckDB() {
    do {
        let db = try Database(store: .inMemory)
        let conn = try db.connect()
        
        let testFile = "/Users/fl/Python/Parquet_View/sample_data.parquet"
        let query = "SELECT * FROM read_parquet('\(testFile)') LIMIT 10"
        
        let result = try conn.query(query)
        
        print("✅ SM-2 PASSED! DuckDB works!")
        print("   Columns: \(result.columns.count)")
        print("   Rows: \(result.count)")
        
        for column in result.columns {
            print("   - \(column.name)")
        }
        
    } catch {
        print("❌ SM-2 FAILED: \(error)")
    }
}
```

3. 在 `ParquetViewApp` struct 的 `body` 開頭調用：

```swift
@main
struct ParquetViewApp: App {
    init() {
        testDuckDB()  // 添加這行
    }
    
    var body: some Scene {
        // ... 原有代碼
    }
}
```

4. 按 `Cmd + R` 運行

5. 查看 Xcode 底部控制台輸出：
   - ✅ 看到 "SM-2 PASSED!" → 成功！
   - ❌ 看到 "SM-2 FAILED" → 失敗，需要 Plan C

## 方法 2: 使用 Swift REPL（快速）

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

# 進入 Swift REPL，加載 DuckDB
swift -I .build/debug -L .build/debug -lDuckDB

# 然後在 REPL 中執行：
import DuckDB
let db = try Database(store: .inMemory)
let conn = try db.connect()
let result = try conn.query("SELECT * FROM read_parquet('/Users/fl/Python/Parquet_View/sample_data.parquet') LIMIT 5")
print(result.count)
```

## 方法 3: 創建單獨的測試 target

在 Xcode 中：
1. File → New → Target → macOS → Command Line Tool
2. Name: "SM2Test"
3. 添加 DuckDB 依賴
4. 複製 TestDuckDBReal.swift 代碼
5. 運行該 target

---

**推薦使用方法 1 - 最簡單直接！**
