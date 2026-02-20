# Parquet View Pro

A fast, native macOS app for viewing data files, powered by **Swift** and **DuckDB**.

## Features

- **Multi-format** — Parquet, CSV, TSV, JSON, JSONL (ndjson)
- **Drag & Drop** — Drop files anywhere to open
- **Tabs** — Open multiple files simultaneously
- **Search & Filter** — Quick text search across all columns or by column
- **Sort** — Click column headers to sort
- **Export** — Export to CSV or Parquet
- **Dark Mode** — Automatic or manual theme switching
- **i18n** — English and 繁體中文
- **Lazy Loading** — Handles large files efficiently (1GB+)
- **CSV Integrity Check** — Detects truncated rows, mismatched columns, encoding issues
- **Security** — SQL injection and path traversal protection

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel

## Build from Source

```bash
# Build
swift build -c release

# Assemble app bundle
APP="Parquet View Pro.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/Parquet-View "$APP/Contents/MacOS/Parquet View Pro"
cp "Parquet Viewer/Info.plist" "$APP/Contents/"

# Run
open "$APP"
```

## Run Tests

```bash
swift test
# 73 tests, 0 failures, 0 skips
```

## Usage

- **Open File** — `Cmd + O` or drag & drop
- **Search** — Type in search bar, press Enter
- **Sort** — Click column header
- **Export** — Toolbar menu → Export as CSV / Parquet
- **Tabs** — `Cmd + T` new tab, `Cmd + W` close tab

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
SwiftUI Views → DuckDBManager → DuckDB-Swift → DuckDB C++ Core
```

Built with Swift Package Manager. No Xcode project required.

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
