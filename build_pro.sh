#!/bin/bash

# Build Parquet View Pro (Single Version)
# Creates DMG installer

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${GREEN}?? Building Parquet View Pro${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"

# Variables
APP_NAME="Parquet View Pro"
BUNDLE_ID="com.parquetview.pro"
VERSION="1.0.0"
DMG_NAME="ParquetViewPro.dmg"
BUILD_DIR=".build/release"

# Step 1: Clean build
echo -e "\n${YELLOW}??  Step 1: Cleaning previous build...${NC}"
swift package clean
rm -rf "$BUILD_DIR/$APP_NAME.app"
rm -f "$DMG_NAME"
echo -e "${GREEN}? Clean complete${NC}"

# Step 2: Build release
echo -e "\n${YELLOW}??  Step 2: Building release...${NC}"
swift build -c release
echo -e "${GREEN}? Build complete${NC}"

# Step 3: Create .app bundle
echo -e "\n${YELLOW}??  Step 3: Creating .app bundle...${NC}"

# Create app structure
APP_DIR="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/Parquet-View" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Parquet File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.data</string>
            </array>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>parquet</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>CSV File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.comma-separated-values-text</string>
            </array>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>csv</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Copy icon if exists
if [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

echo -e "${GREEN}? App bundle created${NC}"

# Step 4: Sign app
echo -e "\n${YELLOW}??  Step 4: Signing app...${NC}"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
echo -e "${GREEN}? App signed${NC}"

# Step 5: Create DMG
echo -e "\n${YELLOW}??  Step 5: Creating DMG...${NC}"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_NAME"
echo -e "${GREEN}? DMG created${NC}"

# Step 6: Generate checksum
echo -e "\n${YELLOW}??  Step 6: Generating checksum...${NC}"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
CHECKSUM=$(cat "$DMG_NAME.sha256" | cut -d' ' -f1)
echo -e "${GREEN}? Checksum: $CHECKSUM${NC}"

# Get DMG size
DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo -e "${GREEN}?? $APP_NAME DMG Size: $DMG_SIZE${NC}"

echo -e "\n${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${GREEN}? Build Complete!${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"

echo -e "\n${GREEN}?? Parquet View Pro:${NC}"
echo -e "   DMG: $(pwd)/$DMG_NAME"
echo -e "   SHA256: $(pwd)/$DMG_NAME.sha256"

echo -e "\n${BLUE}????????????????????????????????????????????????????????????${NC}"
