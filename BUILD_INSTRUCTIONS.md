# Build Instructions - Parquet Viewer (Swift)

Complete step-by-step guide to build and run the Swift version of Parquet Viewer.

## Prerequisites

? macOS 13.0+ (Ventura or later)  
? Xcode 15.0+  
? Swift 6.0+  
? Command Line Tools installed

### Install Command Line Tools

```bash
xcode-select --install
```

## Step 1: Create Xcode Project

Since we can't automate Xcode project creation completely, follow these steps:

### Method A: Using Xcode GUI (Recommended)

1. **Launch Xcode**
```bash
open -a Xcode
```

2. **Create New Project**
   - File ? New ? Project
   - Select **macOS** ? **App**
   - Click **Next**

3. **Configure Project**
   - Product Name: `Parquet Viewer`
   - Team: Select your development team (or None for local testing)
   - Organization Identifier: `com.yourname` (or any reverse domain)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ?? Include Tests: No
   - Click **Next**

4. **Save Location**
   - Navigate to: `/Users/fl/Desktop/ParquetViewerSwift`
   - **Important**: Check "Create Git repository" if you want version control
   - Click **Create**

### Method B: Copy Pre-Created Files

If you prefer, copy the source files we created:

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

# Source files are already in:
# - Parquet Viewer/ParquetViewerApp.swift
# - Parquet Viewer/DuckDBManager.swift
# - Parquet Viewer/ContentView.swift
# - Parquet Viewer/DataTableView.swift
# - Parquet Viewer/SettingsView.swift
# - Parquet Viewer/Info.plist
```

Then create a new Xcode project and replace the generated files with ours.

## Step 2: Add DuckDB-Swift Package

1. **Open Package Dependencies**
   - In Xcode, select your project in the navigator
   - Select the **Parquet Viewer** target
   - Go to **General** tab
   - Scroll to **Frameworks, Libraries, and Embedded Content**

2. **Add Package**
   - Click the **+** button below the frameworks list
   - Choose **Add Package Dependency...**

3. **Enter Package URL**
   ```
   https://github.com/duckdb/duckdb-swift
   ```

4. **Select Version**
   - Dependency Rule: **Up to Next Major Version**
   - Version: `1.1.3` (or latest)
   - Click **Add Package**

5. **Add to Target**
   - Check ?? **DuckDB** under "Add to Target"
   - Click **Add Package**

## Step 3: Configure Info.plist

The `Info.plist` file should already be created with file associations. Verify it contains:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Apache Parquet File</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.apache.parquet</string>
        </array>
    </dict>
</array>
```

## Step 4: Copy Source Files

Make sure all Swift files are in the project:

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

# Check files exist
ls -la "Parquet Viewer/"/*.swift
```

You should see:
- `ParquetViewerApp.swift`
- `DuckDBManager.swift`
- `ContentView.swift`
- `DataTableView.swift`
- `SettingsView.swift`

If files are missing, create them from the provided code.

## Step 5: Build and Run

### Option A: Build in Xcode (Easiest)

1. **Select Target**
   - At the top of Xcode window, select:
   - Target: **Parquet Viewer**
   - Destination: **My Mac** (or your Mac's name)

2. **Build**
   - Press `Cmd + B` to build
   - Wait for build to complete (first build may take 2-3 minutes)

3. **Run**
   - Press `Cmd + R` to run
   - The app should launch!

### Option B: Build from Command Line

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

# Debug build
xcodebuild -scheme "Parquet Viewer" \
  -configuration Debug \
  -destination "platform=macOS" \
  build

# Find the built app
find ~/Library/Developer/Xcode/DerivedData -name "Parquet Viewer.app" -type d

# Run it
open "$(find ~/Library/Developer/Xcode/DerivedData -name 'Parquet Viewer.app' -type d | head -1)"
```

## Step 6: Test File Association

### Quick Test

```bash
# Copy test file
cp /Users/fl/Python/Parquet_View/sample_data.parquet ~/Desktop/test.parquet

# Try to open with your new app
open -a "Parquet Viewer" ~/Desktop/test.parquet
```

### Set as Default App

1. Right-click `test.parquet` in Finder
2. Choose **Get Info**
3. Under "Open with:", select **Parquet Viewer**
4. Click **Change All...**
5. Confirm the change

### Test Double-Click

Double-click `test.parquet` - it should open in Parquet Viewer!

## Step 7: Create Release Build

For distribution, create an optimized release build:

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

# Release build
xcodebuild -scheme "Parquet Viewer" \
  -configuration Release \
  -derivedDataPath ./build \
  build

# The app will be at:
# ./build/Build/Products/Release/Parquet Viewer.app

# Copy to Applications (optional)
cp -R "./build/Build/Products/Release/Parquet Viewer.app" /Applications/
```

## Step 8: Code Signing (Optional but Recommended)

### For Personal Use (Ad-hoc signing)

```bash
APP_PATH="./build/Build/Products/Release/Parquet Viewer.app"

# Sign with ad-hoc signature
codesign --force --deep --sign - "$APP_PATH"

# Verify
codesign --verify --verbose "$APP_PATH"

# Remove quarantine attribute
xattr -cr "$APP_PATH"
```

### For Distribution (Developer ID)

You need an Apple Developer account ($99/year).

```bash
APP_PATH="./build/Build/Products/Release/Parquet Viewer.app"

# List available identities
security find-identity -v -p codesigning

# Sign with Developer ID
codesign --deep --force \
  --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
  --options runtime \
  "$APP_PATH"

# Verify
codesign --verify --verbose "$APP_PATH"
spctl --assess --verbose "$APP_PATH"
```

## Step 9: Create DMG Installer (Optional)

```bash
cd /Users/fl/Desktop/ParquetViewerSwift

APP_PATH="./build/Build/Products/Release/Parquet Viewer.app"
DMG_PATH="./ParquetViewer-1.0.0.dmg"

# Create DMG
hdiutil create -volname "Parquet Viewer" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "? DMG created: $DMG_PATH"
```

## Troubleshooting

### Build Errors

**Error: "Cannot find 'Database' in scope"**
- Solution: Make sure DuckDB package is properly added
- Try: Product ? Clean Build Folder (`Cmd + Shift + K`)

**Error: "No such module 'DuckDB'"**
- Solution: Check Package Dependencies in project settings
- Verify the package was downloaded (may take a minute first time)

**Error: Multiple commands produce 'Info.plist'**
- Solution: Remove duplicate Info.plist from Build Phases
- Go to: Target ? Build Phases ? Copy Bundle Resources
- Remove any duplicate Info.plist entries

### Runtime Errors

**App crashes on launch**
- Check Console.app for crash logs
- Make sure all Swift files compile without warnings
- Try cleaning build folder: `Cmd + Shift + K`

**Can't open Parquet files**
- Verify Info.plist has correct UTI declarations
- Check file path permissions
- Look at Xcode console for error messages

**"Parquet Viewer" is damaged**
```bash
# Remove quarantine
xattr -cr "/Applications/Parquet Viewer.app"
```

## Performance Optimization

For best performance on Apple Silicon:

1. **Build for Release**
   - Always use Release configuration for testing performance
   - Debug builds are 3-5x slower

2. **Whole Module Optimization**
   - Already enabled in Release builds
   - Provides 20-30% speed boost

3. **Strip Debug Symbols**
   ```bash
   strip -x "$APP_PATH/Contents/MacOS/Parquet Viewer"
   ```

## Next Steps

? Build successful ? Test with your Parquet files  
? File associations work ? Try double-clicking  
? Performance good ? Compare with Rust version  
? Ready for use ? Copy to /Applications  

## Verification Checklist

- [ ] App builds without errors
- [ ] App launches successfully
- [ ] Can open Parquet files via Open menu
- [ ] Can double-click Parquet files
- [ ] Can drag & drop files onto dock icon
- [ ] Search/filter works
- [ ] CSV export works
- [ ] Recent files list works
- [ ] Dark mode switches correctly
- [ ] Settings panel opens

## Support

If you encounter issues:

1. Check Xcode console for error messages
2. Review Console.app for crash logs
3. Verify all prerequisites are installed
4. Try cleaning build folder and rebuilding

---

**Happy Building! ??**
