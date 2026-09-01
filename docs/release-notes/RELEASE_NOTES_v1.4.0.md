# Parquet View Pro — Release Notes v1.4.0

**Date**: 2026-09-02
**Requires**: macOS 13.0 (Ventura) or later

## New

- **Upward pagination** — after a jump, scrolling above the window start loads the
  previous page; the sliding window works in both directions with a memory cap
- **Keyboard-reachable sorting** — the column-header context menu offers
  Sort Ascending / Sort Descending (reachable via Full Keyboard Access / VoiceOver);
  clicking headers still toggles
- **`⌘C` copies the selection** directly (previously only inside the right-click menu),
  and **double-clicking a cell copies just that value**
- **Settings keyboard shortcut** — `⌘,` opens Settings; Esc cancels and Return confirms

## Fixed — UI

- The data table **stays mounted during loads**: searching, jumping and scroll-paging
  show an inline progress strip instead of replacing the whole table, so focus, scroll
  position and selection survive — infinite scroll after a jump no longer bounces back
  to the top, and the viewport stays anchored when the memory-capped window slides
- CSV integrity warnings layer over the still-visible table as a sheet once a file is
  loaded (first-load warnings keep the full-screen presentation)
- Errors no longer replace the table when data is on screen — a dismissible banner
  appears above it and the table stays usable; **Retry** reloads the file actually on
  screen (e.g. a repaired copy) and clears a failing filter first
- `⌘F` focuses the search field even when the current search returned zero rows
- Re-opening a file that is already open selects its existing tab instead of loading
  its data into an unrelated tab
- Batch-opening files no longer shows a self-dismissing modal (the new tabs are the
  feedback), selects the **first** opened tab, and handles duplicates correctly
- Repaired ("skip last row") files get a clean `repaired_<name>` instead of a raw UUID
- Table row height follows the font size setting — large fonts no longer clip
- Tab bar items expose accessibility traits (selected state, labeled close button)

## Fixed — behavior

- Sort operations publish their results on the main actor (no more off-main writes to
  UI state)
- Sorting returns to the top of the result set instead of keeping a stale deep scroll
  offset ("sorted, now looking at row 500,000")
- Sorting a column with many duplicate values no longer repeats or drops rows across
  pages (deterministic tiebreakers, capped at 3 keys for performance)

## Performance & robustness

- `swift test --parallel` (the mode CI uses) is stable — test fixtures now use
  per-test UUID directories
- The localization cache is thread-safe (lookups from background threads)

## Platform & quality

- Accessibility labels are localized
- Tests: 106 → **117**, including Parquet export round-trip + self-overwrite guard,
  temp-file cleanup lifecycle, tie-break sort determinism across pages, upward
  pagination, delimiter sniffing, filter reset, extension matrix, settings reload,
  and repair-action parsing

## Known limitations

- 12 bundled locales pending translations for newer strings (English fallback)
- DuckDB 1.1.3 (upgrade pending; newer releases natively support UTF-16 CSV)
