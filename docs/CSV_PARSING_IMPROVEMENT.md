# CSV解析改進記錄

## 日期
2026-01-28

## 問題描述
CSV文件在加載時無法正確分欄，所有數據被壓縮成一列顯示。

### 問題原因
- 使用`read_csv_auto()`函數時，DuckDB的自動檢測機制無法正確識別包含逗號的引號字段
- CSV文件格式：`"信任的基石",1,"00:00:00,000","00:00:02,000","好 我這邊也不用倒CUE"`
- 引號內的逗號被誤認為分隔符

## 解決方案

### 修改內容
修改`DuckDBManager.swift`中的3處CSV讀取邏輯：

1. **loadParquet函數** (第160行)
2. **export函數** (第335行)  
3. **search函數** (第537行)

### 修改前
```swift
fromClause = "read_csv_auto('\(path)', ignore_errors=true)"
```

### 修改後
```swift
fromClause = "read_csv('\(path)', delim=',', quote='\"', escape='\"', header=true, ignore_errors=true, auto_detect=false)"
```

### 參數說明
- `delim=','`: 明確指定逗號為分隔符
- `quote='\"'`: 明確指定雙引號為引用字符
- `escape='\"'`: 明確指定雙引號為轉義字符
- `header=true`: 第一行為標題行
- `ignore_errors=true`: 容錯處理，忽略格式錯誤
- `auto_detect=false`: 禁用自動檢測，使用明確參數

## 技術細節

### DuckDB CSV讀取函數對比

| 函數 | 優點 | 缺點 |
|------|------|------|
| `read_csv_auto()` | 自動檢測格式，使用簡單 | 對複雜CSV格式可能誤判 |
| `read_csv()` | 完全控制解析參數，準確性高 | 需要明確指定所有參數 |

### 為什麼需要明確參數？
1. **引號內的逗號**: CSV標準允許引號內包含分隔符
2. **自動檢測限制**: `read_csv_auto()`可能無法正確處理所有邊緣情況
3. **一致性**: 明確參數確保跨文件的一致解析行為

## 測試結果
- ✅ 成功解析包含引號字段的CSV文件
- ✅ 正確分欄顯示5個欄位：theme, Nr, timeline, Duration, text
- ✅ 引號內的逗號不再被誤認為分隔符
- ✅ 保持向後兼容性，不影響其他CSV文件

## 影響範圍
- CSV文件加載
- CSV文件導出
- CSV文件搜索

## 相關文件
- `./Parquet Viewer/DuckDBManager.swift`
- `./demo/gwen.csv` (測試文件)

## 後續建議

### 1. 增強CSV檢測
考慮添加CSV格式預檢測功能：
```swift
func detectCSVFormat(url: URL) -> CSVFormat {
    // 分析前100行，檢測分隔符、引號類型
    // 返回最佳參數配置
}
```

### 2. 用戶可配置參數
允許用戶在UI中選擇CSV解析參數：
- 分隔符類型（逗號、分號、Tab）
- 引號類型（單引號、雙引號）
- 編碼格式（UTF-8、UTF-16、GBK）

### 3. 錯誤恢復機制
當明確參數失敗時，自動回退到`read_csv_auto()`：
```swift
do {
    // 嘗試明確參數
    result = try conn.query(explicitQuery)
} catch {
    // 回退到自動檢測
    result = try conn.query(autoQuery)
}
```

## 版本信息
- 應用版本: v1.2.0
- DuckDB版本: 1.1.3
- 修改日期: 2026-01-28
