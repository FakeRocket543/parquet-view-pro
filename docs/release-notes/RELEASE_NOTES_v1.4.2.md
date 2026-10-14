# Parquet View Pro — Release Notes v1.4.2

**Date**: 2026-10-14
**Requires**: macOS 13.0 (Ventura) or later

Round-7 deep-review fixes: correctness, security hardening, and UX bugs
found by an independent audit (code + vendored-DuckDB internals).

## Fixed

- **Tabs disabled = dead app** — turning off "Multiple tabs" in Settings
  left the app permanently unable to open any file (no data manager was
  ever created). A standalone manager now backs the no-tabs mode.
- **Sandboxed build** — the app now ships with the App Sandbox enabled
  (`user-selected.read-write` + security-scoped bookmarks). Parsing a
  hostile file can no longer touch anything you didn't open. The
  recent-files list stores security-scoped bookmarks so re-opening still
  works after relaunch.
- **Filename attacks closed** — a file/directory name containing `* ? [`
  or a `key=value` parent folder could make DuckDB's readers glob-expand
  into neighbouring files or inject phantom columns; such paths are now
  staged through a clean symlink. Directories and special files (FIFOs)
  are rejected up front.
- **Crash via corrupted preferences** — a huge `maxRows` defaults value
  could overflow-trap the app at launch; it is now clamped to the
  100…10,000 range.
- **CSV check now reads the tail** — files over 2 MB previously had only
  their first 2 MB integrity-checked, so a truncated last row on a large
  file reported "valid". The tail is sampled too, and "Skip last row"
  works for it. The repair itself is capped at 512 MB instead of an
  unbounded whole-file read.
- **Selection survives scrolling** — loading the next page no longer
  wipes the rows you selected.
- **Language picker** — all 15 bundled locales are selectable (was 3),
  and all 15 tables are now at full key parity (no more English
  fallback for sort-menu and tail-issue strings).
- **Quit confirmation** — no longer a modal dialog that could block
  system logout/restart/shutdown; it is now a sheet on the window.
- **CSV issue dialog** — "Open with external tool" now dismisses the
  issue view instead of leaving it on screen.
- **Concurrency** — database queries run on a dedicated serial queue via
  async suspension instead of a lock held across the query; a long scan
  can no longer stall unrelated operations or cooperative-pool threads.
  All Swift-6 async-lock warnings eliminated.

## Known limitations

- Accessibility tree flooded by menu items on some systems (pre-existing
  since v1.3.0, under investigation).
- DuckDB 1.1.3 — the newest **stable** duckdb-swift release; upstream
  only publishes `v2.x-dev` tags after it, which `from:` versioning
  correctly excludes. Upgrade waits on an upstream stable.

## Quality

- Tests: **129, 0 failures** (+11: standalone manager, glob path, dir
  rejection, maxRows clamp, tail-truncation, drop-final-record,
  temp-file guard, append selection token, locale coverage).
- Build: zero warnings (34 NSLock-in-async warnings eliminated).
