# Parquet View Pro

A fast, native macOS app for viewing data files, powered by **Swift** and **DuckDB**.

## Features

- **Multi-format** — Parquet, CSV, TSV, JSON, JSONL (ndjson)
- **Drag & Drop** — Drop files anywhere to open
- **Tabs** — Open multiple files simultaneously
- **Search & Filter** — Quick text search across all columns or by column
- **Sort** — Click column headers to sort
- **Jump to Row** — Jump directly to any row in large files
- **Infinite Scroll** — Pages load automatically as you scroll (memory-capped window)
- **Export** — Export to CSV or Parquet
- **Dark Mode** — Automatic or manual theme switching
- **i18n** — UI in English / 简体中文 / 繁體中文 with an in-app switcher (Settings ▸ Language; applies after relaunch). 12 further locales are bundled and fall back to English for newer strings.
- **Lazy Loading** — Paged loading (default 1000 rows, configurable in Settings) for large files
- **CSV Integrity Check** — Detects truncated rows, mismatched columns, encoding issues — with repair actions (load anyway / skip last row / open in external editor)
- **Security** — SQL injection and path traversal protection

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel

## Build from Source

```bash
# Build
swift build -c release

# Assemble app bundle (binary + Info.plist + resources bundle + PkgInfo)
APP="Parquet View Pro.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Parquet-View "$APP/Contents/MacOS/Parquet-View"
cp "Parquet Viewer/Info.plist" "$APP/Contents/"
cp -R .build/release/ParquetViewerSwift_ParquetViewLib.bundle "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Run
open "$APP"
```

Note: the executable must be named `Parquet-View` to match `CFBundleExecutable`
in Info.plist, and the `ParquetViewerSwift_ParquetViewLib.bundle` resource bundle
carries the localized strings — a bundle without it falls back to raw keys.

For a fully assembled, signed, DMG-packaged build, use [`build_pro.sh`](build_pro.sh) or [`build_signed_dmg.sh`](build_signed_dmg.sh).

## Run Tests

```bash
swift test
```

103 tests: unit tests (TabManager, DuckDBManager, SecurityHelper, CSVIntegrityChecker),
`LocalizationTests` (key parity, lookup, format specifiers), and `E2ERealFileTests` —
end-to-end tests that generate real Parquet/CSV/JSON fixtures through DuckDB and
drive the actual `DuckDBManager` (type fidelity, pagination, filter/sort interplay,
integrity edge cases, concurrency, security). CI runs on every push
(`.github/workflows/ci.yml`).

## Usage

- **Open File** — `Cmd + O` or drag & drop
- **Search** — Type in search bar, press Enter
- **Sort** — Click column header
- **Jump to Row** — Arrow button next to the row counter (large files)
- **Font Size** — `Cmd + / - / 0`
- **Export** — Toolbar menu → Export as CSV / Parquet
- **Tabs** — `Cmd + T` new tab, `Shift + Cmd + W` close tab, `Cmd + W` close window,
  `Cmd + 1…9` select tab, `Shift + Cmd + [ / ]` previous/next tab
- **Language** — Settings ▸ Language (applies after relaunch)

## Supported Formats

| Format  | Extensions        | DuckDB Function                  |
|---------|-------------------|----------------------------------|
| Parquet | `.parquet`        | `read_parquet()`                 |
| CSV     | `.csv`            | `read_csv()` (auto-detect)       |
| TSV     | `.tsv`            | `read_csv()` (tab-delimited)     |
| JSON    | `.json`           | `read_json_auto()`               |
| JSONL   | `.jsonl`, `.ndjson`| `read_json_auto()` (newline-delimited) |

## Architecture

```
SwiftUI/AppKit Views (NSTableView) → DuckDBManager + CSVIntegrityChecker → duckdb-swift → DuckDB C++ Core
```

Built with Swift Package Manager. No Xcode project required (`open Package.swift`
gives full Xcode support).

## Code Signing (optional)

```bash
codesign --deep --force --sign "Developer ID Application: YOUR_NAME" "Parquet View Pro.app"
codesign --verify --verbose "Parquet View Pro.app"
```

## License

MIT — See [LICENSE](LICENSE)

## Credits

- [DuckDB](https://duckdb.org) — Query engine
- [SwiftUI](https://developer.apple.com/swiftui/) — UI framework
