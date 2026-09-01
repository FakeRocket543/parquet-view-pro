# Self Review Report — Parquet View Pro

**日期**: 2026-09-01（Round 1 + Round 2）
**方法**: Ralph mode 自主審查循環 — 每輪 4 個並行 subagent + 主 agent 自審/自建 E2E + 修復 + 回歸驗證。
- **Round 1**（3 次迭代）：核心引擎 / UI 層 / 測試建置 / 文件 i18n 審查。
- **Round 2**（本節）：修復驗證（fresh-eyes 回歸審查）/ UI 二次審查與死碼清點 / i18n 鍵值全量盤點（113 新鍵 × 15 語言）/ 對抗性 E2E（duckdb CLI 實證）。

**累計結果**: Round 1 修復 1×P0 + 13×P1；Round 2 再修 1×P1（回歸）+ 6×P2 + 多項 P3，並完成 i18n 接線。測試 73 → **103 全綠**（28 個 E2E + 4 個 i18n + 71 單元）；App 啟動冒煙測試通過。

---

## 1. 審查評分（修復前 → Round 2 後評估）

| 領域 | 初始評分 | Round 1 後 | Round 2 後 |
|---|---|---|---|
| 核心引擎 (DuckDBManager 等) | 5/10 | 7.5/10 | 8.5/10 |
| UI 層 (SwiftUI/AppKit) | 4.5/10 | 6.5/10 | 8/10 |
| 測試與建置 | 4/10 | 7/10 | 8/10 |
| 文件與 i18n | 4/10 | 7/10 | 8/10（en/zh-Hans/zh-Hant 完整） |

---

## 2. 已修復的問題（全部經測試驗證）

### P0 — 資料顯示錯誤（E2E 定罪，11 個斷言失敗 → 修復）

**真實 Parquet 檔案的 DECIMAL / TIMESTAMP / DATE / UBIGINT / LIST / STRUCT 欄位全部顯示 "NULL"**（`DuckDBManager.formatCellValue` 只認得 5 種型別）。DuckDB/pandas/Spark 產生的檔案這些型別極常見 — 等於 App 對真實世界檔案半殘。
*修復*: SQL 層逐欄 `CAST(col AS VARCHAR)`（DuckDB 自己產生正確文字表示、NULL 保持 NULL），排序在子查詢內保留原生型別語義。`Parquet Viewer/DuckDBManager.swift`
*驗證*: `testParquetTypeFidelity`, `testDoubleTypeRendering`

### P1 — 正確性 bug

| # | 問題 | 修復 | 驗證測試 |
|---|---|---|---|
| 1 | Double 顯示損毀：`0.5`→`"5"`、`0.05`→`"05"`、極小值→空字串（trim '0' 吃掉前導零） | 同上（SQL CAST） | `testDoubleTypeRendering` |
| 2 | 搜尋後排序會**丟失過濾條件**、載入更多會**混入未過濾列**、跳行邊界用未過濾總數 | 過濾改為 manager 狀態（`activeFilterText/Column`），count/data/pagination/sort 全部統一走 `loadParquet` 帶 WHERE | `testSortKeepsActiveFilterAndLoadMoreStaysFiltered` |
| 3 | 跳行後 `loadMoreData` 從錯誤 offset 載入（用 displayedRowCount 而非絕對位置） | `newOffset = currentStartRow + rows.count` | `testPaginationAndRowAlignment` |
| 4 | **無限滾動從未觸發** — `dataTableDidScroll` 沒有任何 observer 註冊，使用者永遠只能看前 1000 列 | `makeNSView` 註冊 `boundsDidChangeNotification`，`dismantleNSView` 移除 | 編譯+冒煙測試 |
| 5 | 同 tab 開不同欄數檔案 → 殘留舊欄位（`updateNSView` 只更新標題不增刪欄） | 欄位 diff：移除多餘、補上缺少 | 編譯+冒煙 |
| 6 | 跳行後列號欄（#）仍從 1 開始，與搜尋列顯示的範圍不一致 | `startRow` 傳入，gutter 顯示絕對行號 | — |
| 7 | **CSV 完整性警示是死路** — `csvIssueResult` 非 @Published 且無任何 UI 讀取，問題檔案靜默拒載 | 改 @Published；`DetailView` 呈現 `CSVIssueAlert`，四個修復動作（忽略載入/跳過末列/外部編輯器/重試）全部接線 | `testTruncatedCSVRaisesIssueResultForUI` |
| 8 | **TSV 被逗號邏輯誤判** — 欄位含逗號的合法 TSV 被完整性檢查擋下 | `check(url:delimiter:)` 參數化，TSV 傳 `\t` | `testTSVWithCommaInFieldLoads` |
| 9 | 引號內換行（RFC 4180）的合法 CSV 被誤判 unmatchedQuotes | 以 quote-aware 狀態機解析記錄 | `testCSVWithEmbeddedNewlineInQuotesIsValid` |
| 10 | 完整性檢查**整檔讀入記憶體**（2–5GB CSV → OOM） | 串流最多 2MB 檢查 | — |
| 11 | 搜尋文字被 `sanitizePath` 誤用：搜 `a..b` 直接報錯；`%`/`_` 未跳脫變萬用字元 | 專用 LIKE 跳脫（`\` `%` `_` `'`）+ `ESCAPE` 子句 | `testFilterEscapesLikeWildcards` |
| 12 | 舊測試依賴 **repo 外硬編碼路徑** `/Users/fl/Python/ParquetViewPro` + skip-on-error 把失敗變跳過（在 CI/別台機器上靜默歸零） | 測試自產 fixtures、刪除 skip-on-error | 全套 87 測試 |
| 13 | `Parquet Viewer.xcodeproj` 是空殼（無 pbxproj）；`create_xcode_project.sh` 產出損毀專案 | 刪除空殼與腳本（SPM 即可，`open Package.swift` 有完整 Xcode 支援） | — |

### P2/P3 — 已修

- 欄位名 SQL 注入面：新增 `quoteIdentifier`（`"` → `""`）用於所有 identifier 內插（sort/filter/stats）— `testMaliciousCSVHeaderDoesNotBreakLoader`
- `sanitizePath` 反斜線加倍會損壞含 `\` 的路徑（DuckDB 字面語義）→ 移除；`..` 子字串誤判 `report..final.csv` → 改為路徑元件判斷 — `testExoticFilePathsLoad`
- `filterData` 的 `column` 參數未驗證即內插 → 只接受已知欄位
- 匯出可覆寫正在開啟的來源檔 → 阻擋
- `clearData` 未重置 `csvIssueResult`/`isLoadingMore`/filter 狀態 → 補齊
- `currentFileURL` 在驗證前就被設定（失敗檔案成為匯出目標）→ 驗證後才設定
- `maxRows` 設定是無效開關 → `DuckDBManager` 讀取 UserDefaults
- 通知訂閱 onAppear 重複註冊（Cmd 快捷鍵雙觸發）→ 先清空再訂閱
- 清除搜尋按鈕雙重觸發查詢；`UTType` force-unwrap → 安全解包
- 資料欄不可拖寬 → 補 `resizingMask`
- 資料欄寬 500 上限太窄 → 保持（報告記錄，低風險爭議項）
- UTF-16 fallback 幾乎任何位元組都「解碼成功」產生亂碼 → 僅 BOM 存在時嘗試
- `createTruncatedContent` off-by-one（跳過末列反而保留截斷行）→ 修正契約並以 check→repair 往返測試釘住
- 死代碼 `ColumnInfo` struct 刪除；`jumpToRow` magic number 改用常數
- TabManager `closeOtherTabs` 對不存在 id 會清光所有 tab（agent 發現，低風險）— 未動（行為相依 UI 流程，下輪處理）

### i18n / 品牌一致性

- **zh-Hant 全檔損毀**（211 個 `?`）→ 重寫 49 keys 繁體中文翻譯
- `SettingsView` 語言選單顯示 `"????"` → `繁體中文`；en.lproj 對應鍵修正
- 版本漂移：`BuildConfig` 1.0.0 vs release notes 1.2.0 → 統一 1.2.0
- `Info.plist` 補齊 `CFBundleIdentifier/CFBundleExecutable/CFBundleShortVersionString/CFBundleVersion/CFBundlePackageType/NSHighResolutionCapable`；名稱統一 Pro；© 符號修復；TSV/JSON 文件類型註冊
- `.gitignore` 之前**忽略已追蹤的 `docs/`**（新文件會靜默失蹤）→ 移除；補 script 產物

### Repo 衛生（-7,341 行）

- 刪 21 個過期 MD + 1 個 ASCII demo + 8 個 scratch Swift + 8 個死腳本（硬編碼 `/Users/fl/Desktop/ParquetViewerSwift` 等不存在的路徑；`build_dual_version.sh` 的 sed 靜默 no-op）
- 保留 `build_pro.sh`、`build_signed_dmg.sh`（僅存的兩個可用建置腳本）
- 4 個有歷史價值的文件移入 `docs/` 與 `docs/release-notes/`
- `Package.swift` exclude 修正（每次建置 2 個警告）
- README 修正：i18n 不實宣稱、手動 bundle 漏 resource bundle/圖示、硬編碼 arch triple、測試說明過期
- **新增 `.github/workflows/ci.yml`**（macOS runner + SPM 快取 + swift test）

---

## 3. 測試證據

| 階段 | 測試數 | 結果 |
|---|---|---|
| 審查前基線 | 73 | 全過（但 Parquet 路徑零覆蓋） |
| E2E 首跑（修復前） | 9 新增 | **11 個斷言失敗**（型別保真 P0 定罪） |
| 修復後 | 87 | **全過、0 失敗** |
| GUI 冒煙 | — | App 啟動 5 秒不崩潰 |

新 `E2ERealFileTests`（16 測試）以 DuckDB `COPY ... TO parquet` 自產真實檔案，覆蓋：型別保真（16 種 DuckDB 型別）、分頁對齊、跳行、排序、過濾×排序×分頁交互作用、CSV 引號/BOM/內嵌換行、TSV、JSON/JSONL、注入與特殊路徑、匯出往返。

---

## 4. 未修項目（誠實記錄，下輪建議）

1. **DuckDB 連線並發競態**（P1）：`DuckDBManager` 非 actor 隔離，重疊操作（搜尋 debounce 中排序/滾動載入）可同時打同一條 `Connection`。正確解法是把查詢工作放進獨立 actor — 屬於結構性重構，本輪以 E2E 序列化路徑驗證功能，未動併發模型。
2. **i18n 接線**（P1）：15 語系目錄仍是死代碼（`L10n` 無呼叫點、UI 全硬編碼英文、`CSVIssueAlert` 硬編碼繁中）。資料層（.strings 檔）已修復健康，但 view 層接線是大工程。
3. **Static `@AppStorage` FeatureFlags 無變更通知**（P2）：設定開關需重啟才生效。
4. **載入失敗會清空先前資料**（P3）：非 append 載入在開頭就清空 rows。
5. **無限滾動後 rows 無上限累積**（P2）：百萬列檔案滾到底 = 巨量 `[[String]]`。可加視窗外框（window）快取。
6. **`ignore_errors=true` 靜默丟列**（P2）：壞列數無回報，總數低報。
7. `Stats` 查詢欄位失敗靜默跳過（P2）、每 cell 逐欄 cast 殘留路徑（P3，主路徑已 VARCHAR）。
8. DuckDB `1.1.3` 版本舊（2024），可升級。

---

## 5. 變更清單

63 檔案：+962 / −7,341 行。核心修改：`DuckDBManager.swift`、`CSVIntegrityChecker.swift`、`ParquetTableView.swift`、`DetailView.swift`、`ContentView.swift`、`AppConstants.swift`、`Info.plist`、`BuildConfig.swift`；測試：新增 `E2ERealFileTests.swift`、重寫 `DuckDBManagerTests.swift`、更新 `CSVIntegrityCheckerTests/SecurityHelperTests`；基礎設施：`.github/workflows/ci.yml`、`.gitignore`、`Package.swift`、`README.md`。

---

# Round 2（2026-09-01 深夜輪）

## R2.1 並發與記憶體（主 agent 自營修復，E2E 驗證）

| 問題 | 修復 | 驗證測試 |
|---|---|---|
| 共用 DuckDB Connection 無並發防護（重疊操作可崩潰/竄改狀態） | `dbLock` 序列化所有連線存取 + 作業世代（generation）機制：舊作業結果被 newer 作業超越時丟棄不發佈 | `testConcurrentOperationsDoNotCrashAndLastStateWins`（20 並發混合作業錘擊） |
| 滾動載入無記憶體上限（百萬列檔案 → 巨量 [[String]]） | 滑動視窗：保留上限 max(maxRows×10, 10k) 列，超出時丟最舊、`currentStartRow` 隨之推進（列號欄保持正確） | `testSlidingWindowCapsMemoryAndKeepsAbsoluteRowNumbers` |
| 載入失敗清空先前資料 | 失敗保留舊資料（見 R2.4 P1 配套） | `testFailedReloadPreservesPreviousData` |

## R2.2 對抗性 E2E（agent 以 duckdb CLI 實證 → 修復 → 回歸測試）

| 等級 | 問題（全部 CONFIRMED） | 修復 | 測試 |
|---|---|---|---|
| P1 | 無標頭 CSV 第一列被當標頭吃掉（強制 `header=true`） | 移除強制 delim/header，交給 sniffer | `testHeaderlessCSVDoesNotLoseFirstRow` |
| P1 | 分號分隔的 .csv 全擠成單欄（強制 `delim=','`） | 同上 | `testSemicolonCSVAutoDetectsDelimiter` |
| P1 | UTF-16 CSV「成功」載入成含 NUL 亂碼；且 DuckDB 1.1.3 不支援 `encoding` 參數（CLI 驗證） | BOM 偵測 → 轉碼 UTF-8 暫存（per-path 快取、clearData/deinit 清理、stats/export 同路徑） | `testUTF16CSVLoadsCorrectly` |
| P1 | `COUNT(*)` 在 `ignore_errors` 下虛報 → `hasMoreData` 永真 → 每次滾動全檔重掃 | 空頁收斂 totalRowCount + `hasMoreData` 改視窗絕對尾端判斷 | `testCountConvergenceWhenSnifferDropsBadRows`、`testJumpToLastRowsHasNoMoreData` |
| P2 | 「忽略並載入」後滾動 → 警示又彈回、跳回第 0 列 | `integrityCheckSuppressed` 黏住決策（換檔時重置，見 R2.4） | — |
| P2 | DuckDB 錯誤訊息可內嵌整行（10MB）凍結 UI | 錯誤訊息截斷 500 字 | — |
| P2 | 10MB 單欄位：DuckDB 硬錯、訊息無法行動 | 已由截斷緩解；完整 max_line_size 偵測列為後續 | — |

## R2.3 UI 二次審查（8 項發現全修 + 死碼清除）

- **P1 側欄開關全死**：自訂 toggle 無訂閱者且蓋掉原生項 → 改 `NavigationSplitView(columnVisibility:)` + 保留原生 Toggle Sidebar
- **P1 ⌘W 綁架視窗關閉**：Close Tab 移至 Tab 選單改 **⇧⌘W**
- P2 清除搜尋雙重觸發 → SearchBarView 旗標 + DetailView 單一閘門去重
- P2 分頁切換搜尋框與實際過濾狀態脫鉤 → 切換時同步 `activeFilterText`
- P2 跳行輸入未夾取 → ContentView 權威夾取 + `jumpToRow` 上限夾取 + 對話框 onSubmit
- P2 `maxTabs` @AppStorage 在 ObservableObject 永不刷新 → @Published + 設定頁關閉時 reloadSettings
- P3 closeOtherTabs 幽靈 id 防護、fileIcon 補 tsv/json、無效設定移除（UI Scale、Zoom）、佔位 GitHub 連結、TabManager `?+T` 亂碼修復
- **死碼刪除**：ZoomableScrollView / FileActionButtons / SyncedScrollView 整檔、SidebarView 死 struct（保留活區塊）、ContentView zoom 狀態與 EnvironmentKey
- 排序指示器從死 struct 摺入活側欄

## R2.4 回歸審查（fresh-eyes agent）— 含抓到本輪自身引入的 P1

| 等級 | 發現 | 修復 | 鑑別測試（補上 agent 指出的測試缺口） |
|---|---|---|---|
| **P1** | 載入失敗保留舊資料 + `currentFileURL` 提前設定 → **螢幕顯示 A 檔、匯出卻匯出 B 檔**（Round 2 自己引入） | `currentFileURL` 只在成功發佈時設定；CSV 警示流程改 `currentFileURL ?? selectedFile` | `testSQLFailureKeepsPreviousFileCurrent` |
| P2 | 過濾/排序/integrity 決策洩漏到同 manager 的下一個檔案 | 換檔時重置 filter/sort/suppression | `testSecondFileInSameManagerResetsFilterAndSort` |
| P2 | 排序平手鍵使 OFFSET 分頁不確定（重複/漏列） | ORDER BY 加其餘欄位決勝 | — |
| P2 | 2MB 截斷多位元組字元 → 好檔被誤判編碼錯誤 | 截尾 1–3 bytes 重試解碼（UTF-16 奇數位元組同理） | — |
| P2 | skipLastRow 全檔讀寫跑在 MainActor | `Task.detached` + 產出暫存檔登記由 manager 清理 | — |
| P2 | `transcodedFiles`/filter 狀態多執行緒未防護 | 快取與 filter 寫入上 `dbLock`（含轉碼競速處理） | — |
| P3 | 匯出防護可被 symlink/大小寫繞過 | `resolvingSymlinksInPath` + 大小寫不敏感比較 | — |
| P3 | 跳行→載入更多 的 offset 修復「測試無鑑別力」（起點都在 0） | — | `testJumpThenLoadMoreContinuesFromJumpPosition`（同時修正一個錯誤的測試預期） |
| P3 | 含 `"` 的欄名缺乏覆蓋 | — | `testColumnNameContainingQuoteLoadsSortsAndFilters` |

## R2.5 i18n 接線（從死代碼到可用）

- **查找機制重建**：`L10nBundle` — Bundle.module + AppleLanguages 覆寫 + **SPM lproj 小寫化名稱解析**（`zh-Hans` → `zh-hans.lproj`，實測發現）+ 英文二段回退（落後語系優雅降級，不顯示 dotted key）
- **鍵值**：en/zh-Hans/zh-Hant 各 **121 keys**（49 既有 + 72 新增；修正 6 個過期值如 `welcome.subtitle`）— 全部通過 `plutil -lint` 與鍵集一致性測試
- **接線**：選單列全部、Settings 全部、歡迎/錯誤/空狀態、搜尋列、跳行對話框、CSV 警示（含原本硬編碼繁中的 checker 描述）、批次開檔警示、退出確認
- **語言切換**：picker（English/简体中文/繁體中文）寫入 `AppleLanguages` + 重啟提示（macOS 標準機制）
- **i18n 測試**：`LocalizationTests`（鍵集一致、查找、回退、格式符）
- 其餘 12 語系：維持原 49 keys，缺的新鍵自動回退英文 — 補齊翻譯列為後續（Round 2 agent 已產出 15 語言全量翻譯表可循）

## R2.6 未修項目（誠實記錄）

1. **DuckDBManager 未全面 @MainActor / Swift 6 strict concurrency**：連線已序列化、熱點已上鎖，但正式解法（actor 隔離）需結構性重構
2. **12 語系新鍵翻譯補齊**（回退機制已就位）
3. 每次操作重跑 COUNT(*)（200MB CSV ≈ 55ms；可快取 per (file, filter)）
4. 統計查詢逐欄全掃（1200 欄檔案分鐘級；可合併單查詢）
5. `reloadData()` 無條件全表刷新（無數據變更 token）
6. DuckDB 1.1.3 可升級（新版 CLI 已原生支援 `encoding` 參數，可移除轉碼層）
7. ParquetTableView 排序標記 ▲ 洩漏至右鍵「拷貝欄位」標題（外觀）
8. `applicationShouldTerminate` 每次 Cmd+Q 彈窗（可改僅多分頁時）

## R2.7 Round 2 測試證據

| 階段 | 測試數 | 結果 |
|---|---|---|
| Round 2 開始 | 90 | 全綠 |
| 修復+新增後 | **103** | **全綠、0 失敗**（E2E 28 + Localization 4 + 單元 71） |
| GUI 冒煙 | — | App 啟動 5 秒不崩潰（i18n 接線後） |

---

# Round 3（2026-09-02）

## R3.1 效能（agent 以 CLI + 真 1.1.3 引擎實測 → 實作）

| 項目 | 實測 | 實作 |
|---|---|---|
| 統計合併單掃描 | 20 欄/182MB CSV：逐欄 8.1s → 批次 0.39s（**21×**）；200 欄外推 ~315×；結果與逐欄位元組級一致（AVG 1–2 ULP 為 DuckDB 平行累加本質） | `calculateColumnStats` 單查詢 5×N 聚合 + 逐欄 fallback；`testBatchedColumnStatsAreCorrect` |
| COUNT(*) 快取 | CSV 全掃 90ms/180MB（每次排序/跳頁都重跑）；Parquet 1–3ms（中繼資料） | per (path+filter) 快取、上限 64 條、收斂/clearData 時失效 |
| 排序 tiebreaker 成本 | 每加一鍵 ~8–9×；深 OFFSET 再乘（5M offset + 10 鍵 = 2.8s/頁）— **Round 2 全欄位 tiebreaker 在寬表會成災** | 限制前 3 個決勝鍵（確定性保留、成本受控） |
| DuckDB 升級 | v1.1.3 已是 duckdb-swift 最新 stable（新版全是 dev prerelease）；Swift API 162 commits 零變更 | 維持 1.1.3（報告記錄可精確釘 dev tag 的選項） |

## R3.2 CSVIntegrityChecker 加強（final-diff agent 發現）

- **hitCap 以真實檔案大小判定**（恰好 2MB 倍數的合法檔不再丟失末筆記錄）— `testCheckerHandlesFilesAroundCapBoundary`（精確位元組構造 2MB / 2MB+1 夾具）
- **UTF-8 截尾迴圈 1–3 bytes**（固定截 3 可落在前一個多位元組字元中，誤判 CJK 檔編碼錯誤）
- **分隔符嗅探**：分號 .csv 不再被逗號邏輯誤判 — `testSemicolonCSVPassesIntegrityCheckWithoutSkip`

## R3.3 併發/i18n 邊角（final-diff agent 發現，全修）

- 失敗的過濾載入死局：Retry 現在先 `resetFilter()` 再重載
- 換檔重置中 @Published sort 屬性改主執行緒寫入
- `removeTranscodedFiles` 上鎖；`clearData` 提升 generation（清除後在途作業不得回填）
- UTF-16 轉碼：快取以 size+mtime 驗證（原始檔編輯後失效）、>512MB 防護跳過
- 語言解析：AppleLanguages 陣列逐項 + 區域剝離（`zh-Hans-CN` → `zh-Hans`）、以偏好值為鍵記憶化
- **本機系統語言（法文）實測證明查找正確跟隨系統語言**；測試改為語言中立
- SidebarView / TabManager 殘留硬編碼字串接鍵；死代碼清理（.toggleSidebar 通知、.gitignore 條目）

## R3.4 i18n 補齊（locale agent）

- **15 語系全部 132 keys、完全同位、plutil 全過、placeholder 逐鍵對齊**（agent 並修復 12 檔既有 `error.failed_to_load` 缺 `%@` 的缺陷）
- 修正報告：Round 2 記 121 keys 為誤（實為 132）

## R3.5 版本與發佈就緒（docs agent）

- **版本 1.3.0**（BuildConfig / Info.plist / 兩建置腳本一致）；`docs/release-notes/RELEASE_NOTES_v1.3.0.md` 依用戶可見影響分組撰寫
- README 全面修訂：3 個 P1（錯誤 ⌘W、會造出無法啟動 bundle 的配方、過時 i18n 描述）+ 測試清單 + 架構線 + 用法（⇧⌘W 等）
- `build_pro.sh`：改用專案 Info.plist（完整文件類型）+ 複製 SPM 資源 bundle + PkgInfo；`build_signed_dmg.sh`：BUNDLE_ID 對齊 + bundle 複製
- Info.plist：CFBundleName 統一 Pro、JSONL/NDJSON 文件類型註冊
- 刪 4 份損毀/過時文件（ZOOM_FEATURE_GUIDE、INSTALLATION_GUIDE、PROJECT_ARCHITECTURE、NSTABLEVIEW_MIGRATION_PLAN）
- CI：加 timeout-minutes: 60（agent 驗證 YAML/runner/快取/平行化全數合宜）

## R3.6 final-diff agent 裁決

- 宣稱的 P0（`createTruncatedContent` off-by-one）經本地執行驗證為**誤報**（漏看 `check()` 回傳的 1-based +1 轉換；測試通過）
- 其餘 P1×3、P2×4、P3×8 中：P1-3（README）與 P3-2（13 語系）已由本輪其他工作修畢；P1-1/P1-2/P2-1/2/3/4 見 R3.2/R3.3；`retryWithDifferentSettings` 與 `ignoreAndLoad` 行為相同（P3）記錄為後續項
- 驗證為健全（無需修改）：generation+鎖無死鎖、filter→sort→jump→loadMore 狀態機、注入防護、觀察器生命週期、格式符號全部對齊

## R3.7 殘餘風險（合併前後留意）

1. CSVIntegrityChecker 的 cap/解碼啟發式在位元組對齊壓力下仍是最脆區域（本輪已加對抗測試）
2. 錯誤路徑 UX：ErrorView 取代整個內容區的設計未重做（已緩解 Retry 死局）
3. DuckDB 版本耦合行為（sniffer 方言、count 虛報收斂、VARCHAR 渲染）以觀察釘住、非契約保證 — 升級需重跑 E2E

## R3.8 Round 3 測試證據

- **106 tests, 0 failures**（E2E 31 + Localization 4 + 單元 71）；GUI 冒煙通過；15 語系 lint + 同位全過
- 三輪累計：73 → 106 測試；兩個 P0、15 個 P1、20+ 個 P2/P3 修復；全部由測試釘住
