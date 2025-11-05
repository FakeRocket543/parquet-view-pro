# NSTableView Migration Plan

## ?? Overview

**Migration Goal:** Replace SwiftUI-based `DataTableView` with AppKit `NSTableView` to achieve native Freeze Pane functionality with synchronized row numbers and column headers.

**Start Date:** 2025-11-05  
**Stable SwiftUI Version:** Git tag `STABLE_SWIFTUI_V1.0` (commit 517c28a)  
**Stable DMG Backup:** `ParquetViewPro_SwiftUI_STABLE_v1.0.dmg`

---

## ?? Migration Objectives

### Primary Goals
1. ? **Perfect Freeze Pane:**
   - Row numbers frozen on the left (vertical scroll only)
   - Column headers frozen on top (horizontal scroll only)
   - Both synchronized with data area

2. ? **Maintain Performance:**
   - Keep LazyVStack-equivalent virtual scrolling
   - Fast loading for large datasets (100k+ rows)
   - Low memory footprint

3. ? **Feature Parity:**
   - All existing features must work
   - Multi-tab support
   - Zoom functionality (if feasible with NSTableView)
   - Range selection and copy
   - CSV/Parquet read/export

### Secondary Goals
- Native macOS look and feel
- Better scrolling performance
- Potential for future features (sorting, filtering)

---

## ?? Architecture Changes

### Current (SwiftUI)
```
ContentView
  ?? DataTableView (SwiftUI)
       ?? Header Row (HStack)
       ?? Row Numbers (LazyVStack in ScrollView)
       ?? Data Area (LazyVStack in ScrollView)
            ?? ScrollViewReader for sync
```

### Target (AppKit NSTableView)
```
ContentView
  ?? NSViewRepresentable
       ?? NSTableView (AppKit)
            ?? NSTableColumn (automatic freeze pane support)
            ?? NSTableView dataSource protocol
            ?? NSTableView delegate protocol
```

---

## ?? Implementation Steps

### Phase 1: NSTableView Wrapper Creation (Day 1)

#### 1.1 Create `ParquetTableView.swift`
- `NSViewRepresentable` wrapper for `NSTableView`
- Basic table initialization
- Column setup from DuckDB data

**Files to Create:**
- `Parquet Viewer/Views/ParquetTableView.swift`

**Code Skeleton:**
```swift
struct ParquetTableView: NSViewRepresentable {
    let columns: [String]
    let rows: [[String]]
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        
        // Add columns
        for (index, columnName) in columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            column.title = columnName
            tableView.addTableColumn(column)
        }
        
        scrollView.documentView = tableView
        return scrollView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(columns: columns, rows: rows)
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        // Implementation
    }
}
```

#### 1.2 Implement NSTableViewDataSource
- `numberOfRows(in:)`
- `tableView(_:objectValueFor:row:)`

#### 1.3 Implement NSTableViewDelegate  
- `tableView(_:viewFor:row:)`
- Cell formatting and styling

**Estimated Time:** 3-4 hours

---

### Phase 2: Feature Migration (Day 1-2)

#### 2.1 Row Number Column
- Add a frozen column on the left with index `"#"`
- Style to match original design
- Test vertical freeze

**Implementation:**
```swift
// Add row number column
let rowNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rowNumber"))
rowNumberColumn.title = "#"
rowNumberColumn.width = 60
rowNumberColumn.minWidth = 60
rowNumberColumn.maxWidth = 60
tableView.addTableColumn(rowNumberColumn)
```

#### 2.2 Freeze Pane Configuration
```swift
// Freeze first column (row numbers)
if let firstColumn = tableView.tableColumns.first {
    // NSTableView automatically handles frozen columns when properly configured
}
```

#### 2.3 Selection Handling
- Single cell selection
- Range selection (100x100 limit)
- Copy to clipboard

#### 2.4 Context Menu
- "Copy" for selected cells/rows/columns
- "Copy Column Names" for header

**Estimated Time:** 4-5 hours

---

### Phase 3: Performance Optimization (Day 2)

#### 3.1 Virtual Scrolling
- Ensure `NSTableView` only renders visible rows
- Test with large datasets (100k rows)

#### 3.2 Lazy Loading
- Keep pagination with DuckDB `LIMIT`/`OFFSET`
- Load more rows as user scrolls

#### 3.3 Memory Management
- Profile memory usage
- Compare with SwiftUI version

**Estimated Time:** 2-3 hours

---

### Phase 4: Integration with Existing Features (Day 2-3)

#### 4.1 DuckDB Manager Integration
- Replace `DataTableView` calls with `ParquetTableView`
- Ensure data binding works correctly

#### 4.2 Zoom Functionality
- **Challenge:** NSTableView doesn't natively support zoom
- **Options:**
  a. Apply `NSView` scale transform (may break scrolling)
  b. Adjust font size instead of true zoom
  c. Remove zoom feature (simplest)

**Decision Point:** Consult with user

#### 4.3 Tab Management
- Ensure multiple tabs can have separate table instances
- Test switching between tabs

#### 4.4 Settings Integration
- Restore user preferences (column widths, etc.)

**Estimated Time:** 3-4 hours

---

### Phase 5: Testing & Polish (Day 3)

#### 5.1 Functional Testing
- [ ] Open Parquet/CSV files
- [ ] Export to Parquet/CSV
- [ ] Copy cells/rows/columns
- [ ] Range selection
- [ ] Jump to row
- [ ] Multi-tab operations
- [ ] Settings persistence

#### 5.2 Performance Testing
- [ ] 10k rows
- [ ] 100k rows
- [ ] 1M rows (with pagination)
- [ ] Memory usage
- [ ] Scroll smoothness

#### 5.3 UI/UX Testing
- [ ] Freeze pane works correctly
- [ ] Headers sync horizontally
- [ ] Row numbers sync vertically
- [ ] Column resizing
- [ ] Keyboard shortcuts

#### 5.4 Edge Cases
- [ ] Empty files
- [ ] Large column count (>100)
- [ ] Unicode/CJK characters
- [ ] NULL values display

**Estimated Time:** 3-4 hours

---

### Phase 6: Build & Package (Day 3)

#### 6.1 Clean Build
```bash
swift package clean
swift build --configuration release
```

#### 6.2 Code Signing & DMG
```bash
./build_pro.sh
```

#### 6.3 Verification
- Install and test DMG
- Check file associations
- Verify icon and metadata

**Estimated Time:** 1 hour

---

## ?? Known Risks & Mitigation

### Risk 1: NSTableView Performance
**Risk:** NSTableView might be slower than SwiftUI LazyVStack  
**Mitigation:** 
- Profile early in Phase 3
- Keep `LIMIT`/`OFFSET` pagination
- Use `NSTableView` reuse mechanism

### Risk 2: Zoom Feature Loss
**Risk:** NSTableView doesn't support zoom like SwiftUI  
**Mitigation:**
- Discuss with user (acceptable?)
- Consider font size adjustment as alternative
- Keep zoom setting in UI, but disable for NSTableView version

### Risk 3: Integration Complexity
**Risk:** Mixing AppKit and SwiftUI can cause layout issues  
**Mitigation:**
- Use `NSViewRepresentable` properly
- Test in Xcode preview
- Isolate AppKit code

### Risk 4: Tab Switching Issues
**Risk:** Multiple NSTableView instances might conflict  
**Mitigation:**
- Each tab creates independent NSTableView
- Proper cleanup on tab close
- Test tab switching extensively

---

## ?? Rollback Plan

If migration fails or performance degrades:

1. **Git Rollback:**
   ```bash
   git checkout STABLE_SWIFTUI_V1.0
   git checkout -b rollback-nstableview
   ```

2. **Restore DMG:**
   ```bash
   cp ParquetViewPro_SwiftUI_STABLE_v1.0.dmg ParquetViewPro.dmg
   ```

3. **Document Failure:**
   - Update `NSTABLEVIEW_MIGRATION_NOTES.md` with issues
   - Consider alternative approaches

---

## ?? Success Criteria

### Must Have (Go/No-Go)
- ? Perfect freeze pane for row numbers (vertical)
- ? Perfect freeze pane for column headers (horizontal)
- ? Performance ? SwiftUI version (load time, scroll fps)
- ? All existing features work (copy, export, tabs)

### Nice to Have
- ? Zoom functionality preserved
- ? Better scrolling smoothness
- ? Native macOS look

### Deal Breakers
- ? Freeze pane doesn't work correctly
- ? Performance regression >20%
- ? Critical features broken (copy, export)
- ? Memory usage >2x SwiftUI version

---

## ?? Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1: NSTableView Wrapper | 3-4h | Day 1 AM | Day 1 PM |
| Phase 2: Feature Migration | 4-5h | Day 1 PM | Day 2 AM |
| Phase 3: Performance Optimization | 2-3h | Day 2 AM | Day 2 PM |
| Phase 4: Integration | 3-4h | Day 2 PM | Day 3 AM |
| Phase 5: Testing & Polish | 3-4h | Day 3 AM | Day 3 PM |
| Phase 6: Build & Package | 1h | Day 3 PM | Day 3 PM |

**Total Estimated Time:** 16-21 hours (~3 working days)

---

## ?? Reference Documentation

- [NSTableView Documentation](https://developer.apple.com/documentation/appkit/nstableview)
- [NSTableViewDataSource](https://developer.apple.com/documentation/appkit/nstableviewdatasource)
- [NSTableViewDelegate](https://developer.apple.com/documentation/appkit/nstableviewdelegate)
- [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)
- [AppKit-SwiftUI Integration Guide](https://developer.apple.com/tutorials/swiftui/interfacing-with-uikit)

---

## ?? Migration Notes

### Why NSTableView?

**Pros:**
- ? Native freeze pane support (out of the box)
- ? Mature, battle-tested component
- ? Better scrolling performance (potentially)
- ? Built-in column resizing/reordering
- ? Automatic row reuse

**Cons:**
- ? AppKit-SwiftUI bridge complexity
- ? More boilerplate code
- ? Harder to style/customize
- ? Zoom support unclear

**Decision:** Freeze pane is a critical feature that's extremely difficult in pure SwiftUI. The benefits outweigh the costs.

---

## ? Checklist

- [x] Stable SwiftUI version backed up (git tag + DMG)
- [ ] Phase 1: NSTableView wrapper created
- [ ] Phase 2: Features migrated
- [ ] Phase 3: Performance optimized
- [ ] Phase 4: Integrated with existing code
- [ ] Phase 5: Tested thoroughly
- [ ] Phase 6: Built and packaged
- [ ] User acceptance testing passed

---

**Last Updated:** 2025-11-05 23:35  
**Status:** Planning Complete, Ready to Start Phase 1
