# Parquet Viewer - Installation Guide

## Quick Installation

### Option 1: DMG Installation (Recommended)

1. **Download**
   - Locate `ParquetViewer.dmg` in the project directory

2. **Open DMG**
   - Double-click `ParquetViewer.dmg`
   - A new window will open showing the app

3. **Install**
   - Drag "Parquet Viewer" to the Applications folder
   - Wait for copy to complete

4. **First Launch**
   - Navigate to Applications folder
   - **Right-click** on "Parquet Viewer" ? Select **"Open"**
   - Click **"Open"** in the security dialog
   - ?? Important: Don't double-click on first launch (Gatekeeper will block it)

5. **Subsequent Launches**
   - After first launch, you can open normally by double-clicking
   - Or open Parquet/CSV files directly

---

## Security & Verification

### Code Signing
- **Type**: Ad-hoc signature (development)
- **Notarization**: Not notarized (not required for personal use)
- **First Launch**: Must use Right-click ? Open

### Checksum Verification
```bash
# Verify DMG integrity
shasum -a 256 ParquetViewer.dmg

# Compare with ParquetViewer.dmg.sha256
cat ParquetViewer.dmg.sha256
```

**Expected SHA256:**
```
3dea4b5b5d777cb2943f17c92065f5141acb1187df39b352934b1fec5369b3a6
```

---

## File Associations

### Automatic File Associations
After installation, the app will be available for:
- `.parquet` files
- `.csv` files

### Setting as Default Viewer

**For Parquet Files:**
1. Right-click a `.parquet` file
2. Get Info (?+I)
3. Open with: Select "Parquet Viewer"
4. Click "Change All..."

**For CSV Files:**
1. Right-click a `.csv` file
2. Get Info (?+I)
3. Open with: Select "Parquet Viewer"
4. Click "Change All..."

---

## System Requirements

### Minimum Requirements
- **OS**: macOS 13.0 (Ventura) or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel x86_64
- **RAM**: 512 MB free memory
- **Disk Space**: 30 MB for application

### Recommended
- **OS**: macOS 14.0 (Sonoma) or later
- **RAM**: 2 GB free memory (for large datasets)
- **Disk Space**: 100 MB for application and temp files

---

## Features

### Supported File Formats
- ? **Parquet** (`.parquet`)
  - Fast loading
  - High compression
  - Optimized for big data

- ? **CSV** (`.csv`)
  - Auto-detect delimiter
  - Auto-detect headers
  - Supports various encodings

### Export Formats
- Export to CSV
- Export to Parquet
- All format combinations supported

### Key Features
- ?? High-performance virtual scrolling
- ?? Search and filter
- ?? Jump to row (for large datasets)
- ?? Copy row, column, or range
- ?? Multi-language support (English, ????)
- ?? Zoom in/out (Cmd +/-, Cmd 0)
- ?? Keyboard shortcuts
- ?? Native macOS design

---

## First Launch Guide

### Opening the App

**Method 1: From Applications Folder**
```
Applications ? Right-click "Parquet Viewer" ? Open
```

**Method 2: From File**
```
Right-click .parquet or .csv file ? Open With ? Parquet Viewer
```

### Opening a File

1. **Via Menu**
   - File ? Open (?+O)
   - Select a Parquet or CSV file

2. **Via Drag & Drop**
   - Drag file to app window
   - Or drag file to app icon

3. **Via Finder**
   - Right-click file ? Open With ? Parquet Viewer
   - Or double-click (if set as default)

---

## Keyboard Shortcuts

### File Operations
- `?+O` - Open file
- `?+W` - Close window
- `?+Q` - Quit app

### View Operations
- `?++` - Zoom in
- `?+-` - Zoom out
- `?+0` - Reset zoom
- `?+F` - Search
- `?+?+S` - Toggle sidebar

### Data Operations
- `?+C` - Copy selected
- `?+E` - Export
- Click row number - Copy row
- Click column header - Copy column
- Shift+Click cells - Select range (max 100x100)

---

## Troubleshooting

### Issue: "App is damaged and can't be opened"

**Solution 1: Remove Quarantine Flag**
```bash
xattr -cr "/Applications/Parquet Viewer.app"
```

**Solution 2: Right-click to Open**
```
Right-click app ? Open ? Click "Open" in dialog
```

### Issue: "App can't be opened because it is from an unidentified developer"

**Solution:**
```
System Settings ? Privacy & Security ? 
Scroll down ? Click "Open Anyway" next to app name
```

### Issue: App won't launch

**Check 1: System Version**
```bash
sw_vers
# Should be macOS 13.0 or later
```

**Check 2: App Integrity**
```bash
codesign -dvvv "/Applications/Parquet Viewer.app"
# Should show signature info
```

**Check 3: Reinstall**
```
1. Delete app from Applications
2. Empty Trash
3. Reinstall from DMG
```

### Issue: CSV files won't open

**Check 1: File Encoding**
- App supports UTF-8, ASCII, Latin-1
- Try opening in text editor first

**Check 2: File Format**
- Must be valid CSV with consistent columns
- Auto-detection works with most formats

### Issue: Performance problems

**Check 1: File Size**
```
# Check file size
ls -lh yourfile.parquet

# For files > 1GB, use "Jump to Row" feature
```

**Check 2: Memory**
```
# Monitor memory usage
Activity Monitor ? Find "Parquet Viewer"
# Should use ~50-100MB for normal files
```

---

## Uninstallation

### Complete Removal

1. **Delete Application**
   ```
   /Applications/Parquet Viewer.app ? Move to Trash
   ```

2. **Delete Preferences (Optional)**
   ```bash
   rm -rf ~/Library/Preferences/com.parquetviewer.app.plist
   rm -rf ~/Library/Caches/com.parquetviewer.app
   ```

3. **Empty Trash**
   ```
   Finder ? Empty Trash
   ```

---

## Build Information

- **Version**: 1.0.0
- **Build Date**: 2025-11-05
- **DMG Size**: 15 MB
- **Architecture**: Universal (Apple Silicon + Intel)
- **Minimum macOS**: 13.0

---

## Support & Feedback

### Reporting Issues
When reporting issues, please include:
1. macOS version (`sw_vers`)
2. File format and size
3. Steps to reproduce
4. Screenshot if applicable

### Feature Requests
Contact the development team with:
- Feature description
- Use case
- Expected behavior

---

## License

Copyright ? 2025. All rights reserved.

This software is provided "as is", without warranty of any kind.

---

## Changelog

### Version 1.0.0 (2025-11-05)
- ? Initial release
- ? Parquet file support
- ? CSV file support
- ? Export functionality
- ? Search and filter
- ? Zoom feature
- ? Multi-language support
- ? Fixed row numbers column
- ? Performance optimizations

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-05
