# Round 7 — External Deep Review → Fix Plan

**Date**: 2026-10-14. **Input**: independent deep review (main agent + security-reviewer subagent vs vendored DuckDB 1.1.3 sources). Build clean (34 warnings), 118/118 tests green at baseline.

## Findings → planned fix

| # | Sev | Finding | Fix |
|---|---|---|---|
| 1 | Critical | `tabsEnabled=false` → no `DuckDBManager` ever exists (only `FileTab` creates one); `loadFile` no-ops silently | `TabManager.standaloneManager` fallback; `ContentView.dbManager` returns it when tabs off/empty |
| 2 | High | Unsigned artifact is unsandboxed (no entitlements file; `--options runtime` only) while DuckDB 1.1.3 C++ parses hostile files | Add `ParquetViewer.entitlements` (app-sandbox + user-selected.read-write + bookmarks); wire `--entitlements` in build scripts; security-scoped bookmarks for recents |
| 3 | Medium | `read_parquet('path')` glob-expands: `* ? [` filenames expand, `dir/x.parquet` reads whole dir, `key=val` dirs inject hive columns | Symlink into `$TMPDIR` when path has glob chars (leverages existing temp-file cleanup); reject non-regular files |
| 4 | Medium | `maxRows` UserDefaults unclamped → `maxDisplayRows * 10` can overflow-trap (release) | Clamp to `minMaxRows...maxMaxRows` at read |
| 5 | Medium | CSV integrity check reads only head 2 MB → tail-truncated big CSVs pass as valid; `createTruncatedContent` unbounded full-file read | Also sample file tail; cap repair at 512 MB |
| 6 | Medium | NSLock held across `conn.query` (blocks cooperative pool, stalls all ops incl. `clearData` during slow queries); 34 async-lock warnings = Swift 6 errors; `@Published` read off-main under lock while written on main w/o lock = data race | Serial `connQueue` + `withCheckedThrowingContinuation` (suspends instead of blocking); filter/sort/suppression/paginationInFlight → `@MainActor` props; `withLock` for remaining lock scopes |
| 7 | Medium | Plain append pagination clears selection (pendingRowShift nil → semantic reset → deselectAll) | `pendingRowShift = 0` on append; table treats 0 as keep-selection |
| 8 | Medium | `build_pro.sh` embeds stale Info.plist (no TSV/JSON/JSONL doc types, no UTI decl) | Copy repo plist like signed script does |
| 9 | Medium | Language picker offers 3 of 15 shipped locales | Expand `Language` enum to all 15; test asserts coverage |
| 10 | Low | `openWithExternalTool` doesn't dismiss CSV alert (cold-load inline path) | Clear `csvIssueResult` in handler |
| 11 | Low | Modal `runModal` in `applicationShouldTerminate` blocks logout/shutdown | `terminateLater` + async alert callback |
| 12 | Low | Dead-code landmine: `sortDescendingAction` calls `onSortColumn` twice in fallback | Remove bogus second call |
| 13 | Low | `maxRows` setting applies only to new tabs (init-time read), hint silent | Hint text via localized string |
| 14 | Hygiene | dup `hasPreviousData` assign; `maxRecentFiles` unused; stats `errorMessage` lacks 500-char truncation; `validateFilePath` no regular-file check (FIFO hang); `registerTempFile` latent arbitrary-delete | One-liners each |

## Verified-solid (no action)
SQL injection surface (3 correct encoders, verified vs libpg_query `standard_conforming_strings`), generation superseding + publish recheck, export self-overwrite guard, no secrets, tests use self-generated parallel-safe fixtures.

## Ralph-mode protocol
Spawn: 1 mech-fix subagent (ParquetTableView + SettingsView). Self: core fixes → tests → regression review (spawn if model available, else adversarial self-review) → MD report append.
