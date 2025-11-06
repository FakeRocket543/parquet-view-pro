# Cmd+F 功能快速參考

## 🚀 快速開始

### 使用方法
```
按下 ⌘F → 搜尋框高亮 → 輸入關鍵字 → 按 Enter → 查看結果
```

### 快捷鍵
- **⌘F**: 聚焦搜尋框
- **Enter**: 執行搜尋
- **ESC**: 清除焦點

## 🎨 視覺指示

### 焦點狀態
| 元素 | 未聚焦 | 已聚焦 (⌘F 後) |
|------|--------|----------------|
| 放大鏡圖標 | 灰色 | 🔵 藍色 |
| 邊框 | 無 | 🔵 2px 藍色 |
| 背景 | 透明 | 🔵 淡藍色 |

## 📁 相關文件

| 文件 | 說明 |
|------|------|
| `CMD_F_FEATURE_SUMMARY.md` | 完整功能報告 |
| `CMD_F_VISUAL_DEMO.md` | 視覺效果演示 |
| `TEST_CMD_F_FEATURE.md` | 測試指南 |

## 🔧 技術要點

### 核心檔案
- `ParquetViewApp.swift` (行 55-58): 快捷鍵定義
- `ContentView.swift` (行 193-223): 視覺效果
- `ContentView.swift` (行 396-403): 通知處理

### 關鍵代碼
```swift
// 焦點狀態
@FocusState private var isSearchFocused: Bool

// 視覺效果
.foregroundColor(isSearchFocused ? .blue : .secondary)
.background(isSearchFocused ? Color.blue.opacity(0.1) : Color.clear)
.overlay(RoundedRectangle(cornerRadius: 6)
    .stroke(isSearchFocused ? Color.blue : Color.clear, lineWidth: 2))
```

## 🧪 測試清單

- [ ] 按下 ⌘F 搜尋框獲得焦點
- [ ] 視覺效果正確顯示（藍色邊框、圖標、背景）
- [ ] 輸入關鍵字並按 Enter 執行搜尋
- [ ] 搜尋結果正確顯示
- [ ] 清除按鈕正常工作
- [ ] 焦點切換時視覺效果正確更新
- [ ] 深色模式下顯示正常

## 🎯 Git 提交

```bash
61f4047 - 備份: 準備添加 Cmd+F 快速查詢功能優化
bec460c - ✨ 新增功能: Cmd+F 快速查詢視覺增強
5e1ee65 - 📝 文檔: 添加 Cmd+F 功能完成報告
a39b4f9 - 📚 文檔: 添加 Cmd+F 視覺演示說明
```

## 🏗️ 建置與測試

```bash
# 清理並建置
rm -rf .build
swift build -c release

# 運行應用程式
open .build/arm64-apple-macosx/release/Parquet-View

# 或使用腳本
./build_pro.sh
./run_app.sh
```

## ✅ 完成狀態

- ✅ 備份完成
- ✅ 視覺增強實現
- ✅ 建置成功
- ✅ 文檔完整
- ✅ Git 提交完成

## 📞 使用支援

### 常見問題

**Q: 按 ⌘F 沒反應？**  
A: 確保已載入檔案且表格有資料。

**Q: 視覺效果看不清楚？**  
A: 檢查系統深色模式設定，顏色會自動調整。

**Q: 搜尋結果不正確？**  
A: 搜尋功能使用 DuckDB 的 LIKE 查詢，支援通配符。

### 建議設定

- 建議使用預設主題（系統自動）
- 確保已啟用輔助功能（如需要）
- 字體大小可通過 ⌘+ / ⌘- 調整

---

**快速參考版本**: 1.0  
**最後更新**: 2025-11-06  
**狀態**: ✅ 生產就緒
