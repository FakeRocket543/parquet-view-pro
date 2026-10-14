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

---

# Round 4（2026-09-02，v1.3.0 發佈後）

## R4.0 發佈
- `master` → `4d3de8b` 推送 + 標籤 **v1.3.0** 上遠端（release agent 驗證：版本一致、15 語系、筆記屬實、tag 自洽；CI 在私有 Gitea 上為「待 GitHub 鏡像後生效」）
- **Release E2E**：`build_pro.sh` 全跑 — DMG 產出、bundle 可啟動、資源 bundle 內含 15 語系（腳本修復後首次實測）

## R4.1 影響所有使用者的 P1（a11y agent 發現）

| 問題 | 修復 |
|---|---|
| **每次搜尋/滾動載入都把整個表格換成 LoadingView** — 焦點、捲動位置、選取全毀；跳行後無限滾動「回彈到頂部」，實質不可用 | 首次載入後資料區**永不卸載**：載入中顯示內嵌進度條、表格保持互動；CSV 警示改為 sheet 疊加（表格在背後可見） |
| 重複開啟已開檔案 → `addTab` 回 true 但沒建 tab → 資料載進 `tabs.last`（A 分頁標題顯示 B 的資料） | 載入前先查已存在分頁 → 只選取不重載 |

## R4.2 併發（actor agent）— 兩個真缺陷外科修復

- `sortByColumn`/`toggleSort` 在協程池寫 @Published（SwiftUI 契約違反）→ `MainActor.run`
- 排序語義：新排序結果沒有穩定「目前列」→ 排序一律回到 offset 0（原先保留舊 offset 造成「排序後顯示第 50 萬列起」的錯置視口）
- **完整 actor 化設計已備妥**（`@MainActor` manager + 鎖保護 `DuckDBCore` 口袋，含逐步遷移圖）— agent 評估為 borderline，依其建議**暫緩執行**，設計存於本節供後續

## R4.3 測試（audit agent，評級 B+）

- **C1 平行測試修復（CI 阻斷級）**：`swift test --parallel`（CI 用的模式）因共享 fixture 目錄互刪而紅 — 改每類/每測試 UUID 目錄，三次連跑穩定
- **+9 測試（106 → 115）**：Parquet 匯出往返 + 自我覆寫防護、`registerTempFile` 清理生命週期、**平手鍵排序跨頁不重不漏**（mutation 證實的缺口）、`sniffDelimiter` 單元、`resetFilter`、`fromClause`/副檔名矩陣、`reloadSettings`、修復動作鍵值解析
- 弱斷言收緊（filterData 精確斷言 2 列 + 全列匹配）；C5 `L10nBundle` 快取上鎖（背景執行緒 `.localized` 競態）

## R4.4 UX/鍵盤/無障礙快速修復

Settings **⌘,** 指令 + Esc/Return 快捷；⌘F 守衛改 `hasLoadedFile`（搜尋零結果時不再失效）；行高隨字體（大字不再裁切）；Retry 改用 `currentFileURL ?? selectedFile`（修復後的重試不再打回原壞檔）；a11y 標籤在地化

## R4.5 誠實記錄：本輪未修（a11y agent P1-2/3 等）

1. **鍵盤排序與 ⌘C 複製**：排序僅存在於表頭滑鼠點擊；⌘C 只在右鍵選單內有效、單 cell 無法複製 — 需要 View 選單命令 + responder-chain 設計
2. 向上分頁（跳行後往上滾到視窗頂即止）
3. 批次開檔的自動關閉 modal、落在最後一個分頁、重複時計數錯位
4. 視窗外滑動的「快進」artifact（視窗滑移後捲軸錨定）
5. `skipped_<UUID>` 暫存名顯示在側欄
6. tab 無障礙特徵（isSelected、關閉鈕標籤）
7. DuckDBCore actor 重構（設計已備）

## R4.6 Round 4 證據

**115 tests, 0 failures**（E2E 35 + Logic 4 + L10n 4 + 單元 72）+ 平行模式 3 連綠 + GUI 冒煙通過 + release DMG 實測啟動

---

# Round 5（2026-09-02，v1.4.0）

## R5.1 新互動（R4.5 延宕項全數落地）

| 功能 | 實作 |
|---|---|
| **向上分頁** | 滾過視窗頂端自動載入上一頁（prepend + 尾端同上限裁剪）；檔案頂端自然停止 |
| **鍵盤可達排序** | 表頭右鍵選單「依遞增/遞減排序」（FKA/VO 可開）；點擊仍是 toggle；顯式方向走 `sortByColumn(ascending:)` |
| **⌘C 複製** | responder-chain（`@objc(copy:)` 子類別）：表格聚焦時複製選取、搜尋框聚焦時複製文字 — 選單項搶捷徑的方案被 table agent 否決後改採正確機制 |
| **雙擊複製單 cell** | `clickedRow/clickedColumn` 精確定位 |
| 批次開檔 | 移除自動關閉 modal（新分頁即回饋）、**停在第一個開啟的分頁**、重複檔案感知（只選取既有分頁） |
| 修復檔命名 | `repaired_<原名>`（碰撞才加短後綴），不再暴露 UUID |
| Tab 無障礙 | isSelected/isButton 特徵、關閉鈕標籤 + 焦點可見、裝飾圖示隱藏、+ 鈕標籤 |

## R5.2 表格深度 agent 的三個關鍵糾正（含推翻我自己 R5 初版實作）

1. **捲動補償符號相反且會誤觸發**（我的初版以 `startRow` 差值啟發式補償：方向錯 2×、漏 intercell spacing、跳行/排序也會被「補償」到文件底）→ 改為 **manager 發佈 `pendingRowShift` 單次錨定**：nil=語義重置（跳行/過濾/排序 → 清選取）、n=純索引平移（prepend +n / 裁剪 -overflow → **保留選取** + 錨定視窗）；捲動前先 `layoutSubtreeIfNeeded()`、stride 用 `rect(ofRow:)`（含間距）
2. **分頁切換後回呼過期 — 滾動 B 分頁會把資料寫進 A 分頁的 manager**（SwiftUI 結構性身分保留 coordinator，`let` 回呼永不刷新）→ 全部改 `var` 並在 `updateNSView` 每次刷新
3. **分頁 check-then-act 競態**（動量滾動在旗標繞行 MainActor 前連發觸發 → 重複/跳頁）→ `paginationInFlight` 在**同一 dbLock 臨界區**內讀取+設定

其他：欄寬按名跨重建持久化（分頁/檔案切換不再重置 150pt）、表頭左右兩緣都讓給原生拖寬（左緣抓取不再誤觸排序）、cell 重用的鋸齒列殘值漏洞、`reloadToken` 改 `dataVersion`（hash-free 零偽陰性）

## R5.3 DuckDBManager 最終審查 agent

- **2 個 P1 競態**：發佈區塊內重新檢查 generation（clearData 復活 + 雙重 append 都在此關閉）；clearData 重置 `isLoading/isLoadingMore`（被超越的載入不會再清 → 永久轉圈）
- **`loading.appending` 等 8 個鍵從未入庫**（我 R4 用了鍵但沒加 — 每次分頁顯示原始鍵名）→ 8 鍵 ×15 語系補齊（採 R2 翻譯表），進度訊息全部接鍵
- 跨欄 OR 鏈 >1000 欄觸發 `max_expression_depth` → 500 一組分塊
- 死碼清除（ExportFormat displayName/fileExtension、偽 sanitize 分支、currentSortCol）+ 匯出註釋誠實化（匯出全檔，非當前視圖/過濾）

## R5.4 殘餘（誠實記錄）

- 分頁改 `beginUpdates/insertRows` 增量更新（SDK 原生保留選取；現為 reloadData+shift 還原）
- 排序指示改 `setIndicatorImage`（現仍寫在標題文字，右鍵選單需剝除）
- 欄選取的選取保留、`dbLock` 裝飾性鎖清理（通往 @MainActor 重構的前置）
- DuckDBCore actor 重構（設計已備，連兩輪評估為延後）

## R5.5 Round 5 證據

**118 tests, 0 failures**（E2E 37 + Logic 4 + L10n 4 + 單元 73）+ GUI 冒煙通過；15 語系 142 keys lint 全過

---

# Round 6（2026-09-05）— 自行擷圖/自行操作迴圈

## R6.1 環境與方法
- 螢幕錄製權限未授予（需使用者在系統設定手動允許「ZCode Computer Use」）→ 改以 **AX 元素樹 + CGWindowList（地面真相）+ System Events + 功能性探針** 驅動與驗證
- 真實 release bundle 啟動、`open -a` 文件事件、鍵盤互動（⌘F/⌘2/⌘⇧E）

## R6.2 抓到並修復：多視窗堆疊 bug（Round 1 我自己引入）
- **症狀**：`open -a`/Finder 開檔每份文件 +1 個堆疊視窗；被殺掉的 session 還原後啟動即 4–17 個堆疊視窗；AX 樹被選單副本灌爆（1000 元素上限全為 menuitem）
- **根因鏈**：R1 為 Info.plist 補 `CFBundleDocumentTypes`（正確）→ SwiftUI `WindowGroup` 對每個 odoc 事件生成新視窗（錯誤行為浮現）；`onOpenURL` 在 macOS 上正是以「每文件一視窗」的方式接事件的機制
- **修復**：`WindowGroup` → `Window`（單視窗 scene）；文件改由 AppDelegate `application(_:open:)` → `.openFileURL` 通知路由進既有視窗分頁；移除 `.onOpenURL`；實作 `shouldRestoreApplicationState = false` 並清除殘留 savedState
- **驗證（CGWindowList 地面真相）**：launch = **1**、`open types.parquet` = 1、`open big.parquet` = 1 ✅
- **教訓**：修復期間曾以錯誤檔名（`Parquet-View` vs `CFBundleExecutable` 的 `Parquet View Pro`）刷新 bundle，導致「以為已修」實則跑舊二進位；另一次 `git checkout .` 把未 commit 的修復清掉 — 兩者都靠「科學驗證」（探針 + 視窗計數）才定位

## R6.3 i18n 真機驗證
- 系統語言為法文：選單、側欄、歡迎畫面、Tab 選單（Onglet/Sélectionner l'onglet 1-10）全以法文渲染 — Bundle 查找/回退在真機運作 ✅
- 小缺陷記錄：12 個「舊 49 鍵」語系的 `welcome.subtitle` 仍為過期文案（Parquet or CSV），en/zh 已更新 — 待統一

## R6.4 發現但未解：AX 選單樹洪水（既有問題，非本輪回歸）
- 全新啟動即有 **243 個 AXMenuBar / 44,693 個 AXMenuItem**（穩定、不隨查詢增長）；v1.3.0 同樣存在（235 個）— bisect 已排除 R5/R6 回歸
- 影響：VoiceOver 使用者的樹被淹沒；外部 AX 自動化讀不到視窗內容
- 已排除：執行期洩漏（穩定）、R5/R6 變更（v1.3.0 對照）、多實例干擾
- 下一步假設：SwiftUI `.commands` 內容（含 `localizedWithFormat` 動態字串）造成的選單重建、或 AX 伺服器對「每此啟動」的註冊累積；需在乾淨帳號/重開機後對照

## R6.5 狀態
- 118 tests 全綠；commit `fix round 6` 已入 master
- 待使用者：授予螢幕錄製權限後可進行完整視覺截圖迴圈

## R6.6 補充：螢幕錄製授權後的視覺驗證（2026-09-06）
- 使用者授予螢幕錄製權限；以 CGWindowListCreateImage 擷取 App 視窗（不搶前景）
- **型別保真 P0 修復首次肉眼確認**：types.parquet 渲染 0.5 / 0.05 / 123.456789 / -0.25（修復前全為 "NULL"）；DECIMAL 以紫色語義著色
- 法文 i18n 全 UI 生效（Fichier actuel / Fichiers récents / Rechercher...）
- 單視窗多分頁正常（測試檔與使用者真實工作檔案並存）；檔案資訊（13 欄/1 列/2 KB）正確；深色模式正常
- 截圖存 /tmp/pv_gui/（含私人檔名，不入 git）

---

# Round 7 — External Deep Review Fix Round (2026-10-14)

**方法**: 主 agent 全檔案重讀 + security-reviewer subagent（含 vendored DuckDB 1.1.3 parser 驗證）→ findings 筆記（docs/round-7-findings.md）→ 自修 → 回歸 → 自審 diff（修正 1 個自造 bug：UTF-16+glob 檔案 staging 順序錯誤）→ MD 報告。

**驗證**: 118 → **129 tests 全綠**；build 警告 34 → **0**；失敗測試 `testDirectoryNamedCSVRejectedNotReadAsDataset` 在首輪發現 regular-file check 未落地，補上後轉綠。

## 修復清單

### Critical
- **tabsEnabled=false 死路**：`DuckDBManager` 只在 `FileTab` 內建立 → 關閉分頁功能後 `loadFile` 永遠 no-op。`TabManager.standaloneManager`（lazy）+ `currentDBManager` fallback（TabManager.swift:60-68；測試 `testCurrentDBManagerFallsBackToStandaloneWhenNoTabs`）。

### High
- **App Sandbox**：新增 `ParquetViewer.entitlements`（app-sandbox + user-selected.read-write + bookmarks.app-scope）；兩支 build script 接 `--entitlements`；`build_pro.sh` 內嵌過期 plist 改為複製 repo `Info.plist` + PlistBuddy 修補。recents 改用 security-scoped bookmarks（ContentView.swift）。

### Medium
- **Glob/hive 注入**：`effectiveQueryURL` 對 `*?[` 檔名或 `key=val` 父目錄走 `$TMPDIR` symlink staging（DuckDBManager.swift:887-897, stageForQuery）；UTF-16 transcode 先於 staging（自審抓回的順序 bug）。測試 `testFileWithGlobCharsInNameLoads`。
- **非正規檔案**：`validateFilePath` 要求 `.typeRegular` — 目錄當 dataset 讀、FIFO 無限阻塞全部杜絕（AppConstants.swift:138-148；`testDirectoryNamedCSVRejectedNotReadAsDataset`）。
- **maxRows clamp**：UserDefaults 值夾到 min…max，溢出 trap 消失（DuckDBManager.swift:100-106；`testMaxRowsClampedFromDefaults`）。
- **CSV tail 採樣**：>2MB 檔案補讀檔尾、僅判定最後一筆記錄（無絕對行號 → lastValidRowIndex=-1 代表「丟棄末行」）；`createTruncatedContent` 512MB 上限（CSVIntegrityChecker.swift:231-274, tailLastRecordStatus）。新增 l10n keys `csv.issue.truncated_tail` / `unmatched_quotes_tail`（en/zh-Hans/zh-Hant 三表，其餘 12 locale 依政策 fallback en）。
- **同步重構**：`connQueue` serial DispatchQueue + continuation 取代跨查詢 NSLock（不再阻塞 cooperative pool；filter/排序等操作即時開始而非等查詢完）；`activeFilter*`/`integrityCheckSuppressed`/`paginationInFlight`/`hasMoreData`/`clearData`/`filterData`/`resetFilter` 改 `@MainActor`；publish 檢查+寫入在同一臨界區（loadParquet:411+）；34 個 async-lock 警告歸零。
- **append 保留選取**：`pendingRowShift = 0`（DuckDBManager.swift:460-463）+ table 接受 0 shift（ParquetTableView.swift:224-228）；`testAppendPageKeepsSelectionToken`。
- **語言選單 3→15**：Language enum 補齊全部 shipped locales（SettingsView.swift:198-238）；`testLanguagePickerCoversAllShippedLocales` 以 bundle 內 .lproj 實盤比對。

### Low
- `openWithExternalTool` 關閉 alert（DetailView.swift:256-260）
- 離開確認改非同步 sheet + `terminateLater`（ParquetViewApp.swift:225-243）
- `sortDescendingAction` fallback 重複呼叫移除（ParquetTableView.swift:645-648）
- `selectTab` 負 index 防護（ContentView.swift:646）
- `DataConstants.maxRecentFiles` 實際使用；`registerTempFile` 限定 tmpdir（防任意刪除原語）；stats errorMessage 套用 500 字元截斷（Self.truncated）
- 重複 `hasPreviousData` 指派、clearData 重複行清除

## 新增測試（+11）
standaloneManager×2、glob 檔名、目錄拒絕、maxRows clamp、tail-truncated×2、drop-final-record、tempFile guard、append shift token、locale 覆蓋。

## 遺留（未動）
- AX menu-item flood（v1.3.0 既有）：R6 量測為「穩定、不隨查詢增長」（fresh launch 243 menubars/44,693 items）；需乾淨帳號/重開機對照以分辨 AX server 累積註冊 vs 真實洩漏 — 無法盲修
- DuckDB 1.1.3 升級：**上游已確認** duckdb-swift 最新 stable 即 v1.1.3（更新的 tag 全為 `-dev` pre-release，`from:` 語義不會選取）— 需待上游發版
- `selectTab` userInfo index 來源仍僅限 app 內部 menu

## Round 7 補充（同日）
- **15 語系 keyset 全對齊**：補 12 語系缺失的 4 鍵（`table.sort_*` + `csv.issue.*_tail`），`testAllShippedLocalesHaveIdenticalKeySets` 改為全 15 語系比對 — 原「12 locale fallback en」遺留項已關閉
- Entitlements 已在簽名 binary 上驗證（sandbox + bookmarks + user-selected.rw）
