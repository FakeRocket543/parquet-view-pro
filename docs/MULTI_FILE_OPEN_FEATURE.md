# 多重檔案開啟功能

## 📋 功能概述

**版本**: v1.2.0  
**新增日期**: 2025-11-06  
**功能**: 支援同時選擇並開啟多個 Parquet/CSV 檔案

## ✨ 功能特色

### Pro 版本功能
- 🗂️ **多重檔案選擇**: 在檔案選擇對話框中選擇多個檔案
- 📑 **自動分頁開啟**: 每個檔案在獨立分頁中開啟
- 🎯 **智能分頁管理**: 自動處理空分頁和分頁上限
- 💬 **友好提示訊息**: 顯示開啟結果和失敗原因
- ⚡ **批次處理**: 高效處理多個檔案

### 免費版本
- 📄 **單檔案開啟**: 選擇多個檔案時只開啟第一個

## 🎯 使用方式

### 方法 1: 開啟檔案按鈕
1. 點擊側邊欄的 "Open" 按鈕
2. 或按下 `Cmd + O`
3. 在對話框中：
   - 按住 `Cmd` 鍵點擊選擇多個檔案
   - 或按住 `Shift` 鍵選擇連續的檔案
4. 點擊 "Open" 按鈕

### 方法 2: 拖拽多個檔案
1. 選擇多個 `.parquet` 或 `.csv` 檔案
2. 拖拽到應用程式圖標或視窗
3. 自動在分頁中開啟所有檔案

## 📊 功能行為

### Pro 版本（tabsEnabled = true）

#### 場景 1: 選擇多個檔案（分頁未滿）
```
選擇 3 個檔案: data1.parquet, data2.parquet, data3.parquet
↓
檔案選擇對話框顯示: "Select one or more Parquet/CSV files to view"
↓
點擊 Open
↓
結果:
├─ Tab 1: data1.parquet（更新當前空分頁或創建新分頁）
├─ Tab 2: data2.parquet（創建新分頁）
└─ Tab 3: data3.parquet（創建新分頁並切換到此分頁）
↓
顯示成功訊息: "Successfully opened 3 files in separate tabs."
（自動 2 秒後關閉）
```

#### 場景 2: 選擇檔案超過分頁上限
```
當前狀態: 已有 8 個分頁，上限 10 個
選擇 5 個檔案
↓
結果:
├─ 成功開啟: 2 個檔案（達到上限 10）
└─ 失敗: 3 個檔案
↓
顯示警告訊息:
"Some Files Not Opened"
Successfully opened: 2 file(s)
Failed to open: 3 file(s)

Reason: Tab limit (10) reached.

Failed files:
- data3.parquet
- data4.parquet
- data5.parquet

Tip: Increase tab limit in Settings or close some tabs.
```

#### 場景 3: 當前分頁為空
```
當前狀態: 1 個空分頁（Untitled）
選擇 3 個檔案
↓
結果:
├─ Tab 1: data1.parquet（更新當前空分頁，不創建新分頁）
├─ Tab 2: data2.parquet（創建新分頁）
└─ Tab 3: data3.parquet（創建新分頁並切換到此）
↓
總分頁數: 3（節省了 1 個分頁）
```

### 免費版本（tabsEnabled = false）

```
選擇多個檔案: data1.parquet, data2.parquet, data3.parquet
↓
檔案選擇對話框顯示: "Select a Parquet or CSV file to view"
↓
點擊 Open
↓
結果:
只開啟 data1.parquet（第一個檔案）
其他檔案被忽略
```

## 🔧 技術實現

### 核心修改

#### 1. NSOpenPanel 設定
```swift
let panel = NSOpenPanel()
panel.allowsMultipleSelection = true  // ✅ 允許多重選擇

// 動態訊息
panel.message = FeatureFlags.tabsEnabled 
    ? "Select one or more Parquet/CSV files to view"
    : "Select a Parquet or CSV file to view"
```

#### 2. 檔案處理邏輯
```swift
if panel.runModal() == .OK {
    let urls = panel.urls  // 取得所有選擇的 URL
    
    if urls.isEmpty { return }
    
    // Pro 版本: 多檔案處理
    if FeatureFlags.tabsEnabled && urls.count > 1 {
        openMultipleFiles(urls: urls)
    } else {
        // 單檔案處理
        if let url = urls.first {
            loadFile(url: url)
        }
    }
}
```

#### 3. 多檔案批次處理
```swift
private func openMultipleFiles(urls: [URL]) {
    var successCount = 0
    var failedFiles: [String] = []
    
    for url in urls {
        // 檢查分頁上限
        if tabManager.tabs.count >= tabManager.maxTabs {
            failedFiles.append(contentsOf: urls.dropFirst(successCount)
                .map { $0.lastPathComponent })
            break
        }
        
        // 添加到最近檔案
        addToRecentFiles(url)
        
        // 處理第一個檔案（可能更新空分頁）
        if successCount == 0, 
           let currentTab = tabManager.currentTab, 
           currentTab.fileURL == nil {
            selectedFile = url
            _ = tabManager.updateCurrentTab(fileURL: url)
            Task {
                await dbManager.loadParquet(url: url)
            }
        } else {
            // 創建新分頁
            if tabManager.addTab(fileURL: url) {
                // 最後一個檔案：切換到該分頁
                if url == urls.last {
                    selectedFile = url
                    Task {
                        await dbManager.loadParquet(url: url)
                    }
                }
            } else {
                failedFiles.append(url.lastPathComponent)
                continue
            }
        }
        
        successCount += 1
    }
    
    // 顯示結果通知
    showResultAlert(successCount: successCount, failedFiles: failedFiles)
}
```

### 智能功能

#### 1. 空分頁優化
- **問題**: 避免不必要的空分頁
- **解決**: 第一個檔案優先更新當前空分頁

#### 2. 分頁上限處理
- **問題**: 超過上限時檔案丟失
- **解決**: 
  - 開啟盡可能多的檔案
  - 記錄失敗的檔案
  - 顯示詳細錯誤訊息

#### 3. 最後檔案聚焦
- **問題**: 多檔案開啟後不知道看哪個
- **解決**: 自動切換到最後一個開啟的分頁

#### 4. 自動關閉通知
- **問題**: 成功通知需要手動關閉
- **解決**: 2 秒後自動關閉成功訊息

## 📝 使用者介面

### 檔案選擇對話框

#### Pro 版本
```
┌─────────────────────────────────────────────┐
│  Select one or more Parquet/CSV files      │
│                                             │
│  📁 Documents                               │
│    ☐ data1.parquet                         │
│    ☑ data2.parquet    ← Cmd+點擊選擇      │
│    ☐ data3.parquet                         │
│    ☑ data4.parquet    ← 多重選擇          │
│                                             │
│           [Cancel]  [Open]                  │
└─────────────────────────────────────────────┘
```

#### 免費版本
```
┌─────────────────────────────────────────────┐
│  Select a Parquet or CSV file to view      │
│                                             │
│  📁 Documents                               │
│    ☐ data1.parquet                         │
│    ☑ data2.parquet    ← 只能選一個        │
│    ☐ data3.parquet                         │
│                                             │
│           [Cancel]  [Open]                  │
└─────────────────────────────────────────────┘
```

### 成功訊息（Pro 版本）

```
┌─────────────────────────────────────────┐
│  ✅ Files Opened Successfully           │
│                                         │
│  Successfully opened 3 files in         │
│  separate tabs.                         │
│                                         │
│              [OK]                       │
│                                         │
│  （自動 2 秒後關閉）                    │
└─────────────────────────────────────────┘
```

### 部分失敗訊息（Pro 版本）

```
┌─────────────────────────────────────────┐
│  ⚠️  Some Files Not Opened              │
│                                         │
│  Successfully opened: 2 file(s)         │
│  Failed to open: 3 file(s)              │
│                                         │
│  Reason: Tab limit (10) reached.        │
│                                         │
│  Failed files:                          │
│  - data3.parquet                        │
│  - data4.parquet                        │
│  - data5.parquet                        │
│                                         │
│  Tip: Increase tab limit in Settings    │
│  or close some tabs.                    │
│                                         │
│              [OK]                       │
└─────────────────────────────────────────┘
```

## 🔄 工作流程範例

### 範例 1: 批次資料分析

**情境**: 需要比較 5 個不同時間的資料檔案

```
1. 按下 Cmd+O 開啟檔案對話框
2. 按住 Cmd 鍵，選擇：
   - sales_jan.parquet
   - sales_feb.parquet
   - sales_mar.parquet
   - sales_apr.parquet
   - sales_may.parquet
3. 點擊 Open
4. 結果：5 個分頁，每個顯示一個月的資料
5. 使用 Cmd+Shift+[ / ] 快速切換分頁比較
```

### 範例 2: 專案資料載入

**情境**: 專案包含多個資料表

```
1. 打開專案資料夾
2. 選擇所有 Parquet 檔案（Cmd+A）
3. 拖拽到 Parquet View Pro 圖標
4. 所有資料表自動在分頁中開啟
5. 使用 Cmd+1~9 快速切換到特定分頁
```

## 📊 效能考量

### 記憶體管理
- ✅ **延遲載入**: 只載入當前查看的分頁資料
- ✅ **自動釋放**: 切換分頁時自動釋放非活躍資料
- ✅ **分頁上限**: 預設 10 個分頁，防止記憶體溢出

### 載入效能
- ✅ **非同步載入**: 檔案載入不阻塞 UI
- ✅ **最後聚焦**: 只有最後一個檔案立即載入
- ✅ **按需載入**: 其他檔案在切換分頁時才載入

## ⚙️ 設定選項

### 分頁上限（Pro 版本）
```
Settings → Tabs → Maximum Tabs
預設: 10
範圍: 1-50
建議: 10-20（視記憶體而定）
```

## 🐛 已知限制

### 1. 分頁上限
- **限制**: 最多同時開啟的分頁數
- **原因**: 記憶體管理和效能考量
- **解決**: 在設定中增加上限或關閉不需要的分頁

### 2. 免費版本限制
- **限制**: 只能開啟單一檔案
- **原因**: 功能區分
- **解決**: 升級到 Pro 版本

## 📈 未來改進

### v1.3.0 計劃
- 🔄 **拖拽排序**: 分頁拖拽重新排序
- 📌 **固定分頁**: 防止意外關閉重要分頁
- 🎨 **分頁群組**: 相關分頁組織成群組
- 💾 **會話儲存**: 儲存當前所有分頁，下次啟動恢復

### v1.4.0 計劃
- 🔍 **跨分頁搜尋**: 在所有開啟的檔案中搜尋
- 📊 **分頁概覽**: 顯示所有分頁的縮圖預覽
- ⚡ **快速切換**: 快速搜尋並切換到特定分頁

## 🧪 測試指南

### 測試案例 1: 基本多檔案開啟
```
1. 準備 3 個測試檔案
2. 按 Cmd+O
3. 選擇所有 3 個檔案
4. 點擊 Open
5. 驗證：
   - 3 個分頁被創建
   - 每個分頁顯示對應檔案
   - 自動切換到最後一個分頁
   - 顯示成功訊息
```

### 測試案例 2: 超過分頁上限
```
1. 設定分頁上限為 5
2. 已開啟 4 個分頁
3. 嘗試開啟 3 個新檔案
4. 驗證：
   - 只有 1 個檔案被開啟
   - 顯示部分失敗訊息
   - 列出 2 個失敗的檔案
   - 提供解決建議
```

### 測試案例 3: 空分頁優化
```
1. 啟動應用程式（1 個空分頁）
2. 選擇 3 個檔案開啟
3. 驗證：
   - 總共 3 個分頁（不是 4 個）
   - 第一個檔案更新了空分頁
   - 沒有殘留空分頁
```

### 測試案例 4: 免費版本行為
```
1. 設定 tabsEnabled = false
2. 選擇多個檔案
3. 驗證：
   - 只開啟第一個檔案
   - 其他檔案被忽略
   - 沒有錯誤訊息
```

## 📚 相關文檔

- `TabManager.swift` - 分頁管理邏輯
- `ContentView.swift` - UI 和檔案開啟邏輯
- `BuildConfig.swift` - 功能開關配置

---

**功能版本**: v1.2.0  
**實現日期**: 2025-11-06  
**狀態**: ✅ 完成並測試通過  
**Pro 功能**: 是
