# Parquet View Pro — Release Notes v1.3.0

**Date**: 2026-09-02
**Requires**: macOS 13.0 (Ventura) or later

## New

- **UI language switcher** in Settings — English / 简体中文 / 繁體中文 (applies after relaunch); menus, settings, dialogs, and alerts fully localized
- New **Tab menu**: Close Tab `⇧⌘W` (`⌘W` is reserved for closing the window again), Close Other/All Tabs, `⇧⌘[` / `⇧⌘]` to switch tabs
- CSV integrity warnings now offer **working repair actions**: load anyway / skip last truncated row / open in external editor / retry

## Fixed — data correctness

- DECIMAL, TIMESTAMP, DATE, UBIGINT, LIST and STRUCT columns no longer display as NULL; doubles like `0.5` no longer render as `5`
- Sorting after a search no longer discards the filter; "load more" never mixes in unfiltered rows
- Headerless CSV no longer loses its first row; semicolon-delimited `.csv` files auto-detect their delimiter
- UTF-16 (BOM) CSV files load correctly instead of showing NUL garbage
- Legal CSV with quoted newlines and TSV with commas in fields are no longer falsely flagged as corrupt
- Search terms containing `%`, `_`, or `..` no longer error or wildcard-mismatch
- A failed load no longer wipes the previously opened file, and export can no longer target the wrong file (or overwrite the open source file)
- Jump-to-row keeps row numbers, pagination offsets, and the row counter consistent

## Fixed — UI

- **Infinite scroll now actually triggers** (previously stuck after the first 1,000 rows), with a memory-capped sliding window and correct absolute row numbers
- Sidebar toggle restored to the native macOS control; columns update correctly when a tab opens files with different schemas
- "Ignore and load" decision now sticks while scrolling a warning-flagged file
- Max-Rows and Max-Tabs settings take effect without a full relaunch of the app (new tabs)

## Performance & robustness

- CSV integrity check streams at most 2 MB instead of reading multi-GB files into memory
- **Column statistics run in a single table scan** instead of one scan per column
- Row counts are cached per file+filter — sorting/jumping/paging no longer re-run full-file `COUNT(*)`
- Concurrent operations (search debounce + sort + scroll-load) are serialized behind a connection lock; stale results are discarded
- DuckDB error messages truncated (huge single-cell files no longer freeze the UI); row counts converge when the sniffer skips bad rows

## Platform & quality

- Rebuilt the corrupted zh-Hant catalog; en / zh-Hans / zh-Hant at full key parity (format-specifier tested); 12 more locales degrade gracefully to English
- Completed Info.plist (identifier, executable, versions, TSV/JSON/JSONL document types); build scripts produce launchable, localized bundles
- Tests: 73 → **100+** (real-file E2E, localization, unit) with self-generated fixtures and no machine-specific paths; GitHub Actions CI on every push
- Removed the empty Xcode project shell, dead scripts and stale docs (~7,500 lines)

## Known limitations

- 12 bundled locales pending translations for newer strings (English fallback)
- DuckDB 1.1.3 (upgrade pending; newer releases natively support UTF-16 CSV)
