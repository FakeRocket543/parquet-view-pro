# Parquet View Pro — Release Notes v1.4.1

**Date**: 2026-10-14
**Requires**: macOS 13.0 (Ventura) or later

Patch release on top of v1.4.0: single-window behavior, localization
coverage, and documentation accuracy.

## Fixed

- **Single-window app** — opening documents (Finder double-click, `open -a`,
  drag & drop) no longer spawns a stack of windows; every file opens as a
  tab in the existing window. Saved-state restoration that resurrected
  killed sessions as a pile of windows is disabled.
- **Localization** — `welcome.subtitle` updated to the "data file" wording
  in all 12 remaining locales (previously still said "Parquet or CSV"
  while en/zh-Hans/zh-Hant had moved on).

## Known limitations

- Accessibility tree flooded by menu items on some systems (pre-existing
  since v1.3.0, under investigation; VoiceOver users affected).
- 12 bundled locales still fall back to English for strings newer than
  v1.3.0.
- DuckDB 1.1.3 (upgrade pending; newer releases natively support UTF-16
  CSV).

## Quality

- Tests: **118, 0 failures** (serial + `--parallel` CI mode).
- Signed with Developer ID, notarized by Apple, stapled — Gatekeeper-clean
  on first launch.
