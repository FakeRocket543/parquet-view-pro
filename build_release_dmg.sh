#!/bin/bash

# Parquet Viewer - Release Build & DMG Package Script
# Builds, signs, and packages the app as DMG

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="Parquet Viewer"
BUNDLE_ID="com.parquetviewer.app"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="ParquetViewer"
DMG_OUTPUT="${PROJECT_DIR}/${DMG_NAME}.dmg"
TEMP_DMG_DIR="${PROJECT_DIR}/.dmg_temp"

echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${BLUE}   Parquet Viewer - Release Build & DMG Package${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}??  Step 1: Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "${TEMP_DMG_DIR}"
rm -f "${DMG_OUTPUT}"
swift package clean
echo -e "${GREEN}? Clean complete${NC}"
echo ""

# Step 2: Build Release
echo -e "${YELLOW}??  Step 2: Building release version...${NC}"
swift build -c release
echo -e "${GREEN}? Build complete${NC}"
echo ""

# Step 3: Create .app bundle
echo -e "${YELLOW}??  Step 3: Creating .app bundle...${NC}"

# Create app structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/Parquet-View" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright ? 2025. All rights reserved.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Parquet File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.apache.parquet</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>CSV File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.comma-separated-values-text</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>org.apache.parquet</string>
            <key>UTTypeDescription</key>
            <string>Parquet File</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>parquet</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Copy icon if exists
if [ -f "${PROJECT_DIR}/assets/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi

echo -e "${GREEN}? App bundle created${NC}"
echo ""

# Step 4: Sign the app
echo -e "${YELLOW}??  Step 4: Signing app (ad-hoc)...${NC}"

# Remove extended attributes
xattr -cr "${APP_BUNDLE}"

# Ad-hoc sign
codesign --force --deep --sign - "${APP_BUNDLE}"

echo -e "${GREEN}? App signed${NC}"
echo ""

# Step 5: Create DMG
echo -e "${YELLOW}??  Step 5: Creating DMG...${NC}"

# Create temporary directory for DMG contents
mkdir -p "${TEMP_DMG_DIR}"

# Copy app to temp directory
cp -R "${APP_BUNDLE}" "${TEMP_DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
               -srcfolder "${TEMP_DMG_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_OUTPUT}"

# Clean up
rm -rf "${TEMP_DMG_DIR}"

echo -e "${GREEN}? DMG created${NC}"
echo ""

# Step 6: Calculate checksum
echo -e "${YELLOW}??  Step 6: Generating checksum...${NC}"
CHECKSUM=$(shasum -a 256 "${DMG_OUTPUT}" | awk '{print $1}')
echo "${CHECKSUM}  ${DMG_NAME}.dmg" > "${DMG_OUTPUT}.sha256"
echo -e "${GREEN}? Checksum: ${CHECKSUM}${NC}"
echo ""

# Summary
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${GREEN}? Release build complete!${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo ""
echo -e "${GREEN}?? Output files:${NC}"
echo -e "   DMG: ${DMG_OUTPUT}"
echo -e "   SHA256: ${DMG_OUTPUT}.sha256"
echo ""
echo -e "${GREEN}?? Installation:${NC}"
echo -e "   1. Open ${DMG_NAME}.dmg"
echo -e "   2. Drag '${APP_NAME}' to Applications folder"
echo -e "   3. First launch: Right-click ? Open (bypass Gatekeeper)"
echo ""
echo -e "${GREEN}?? Security:${NC}"
echo -e "   - Signed: Ad-hoc (development)"
echo -e "   - Notarization: Not required for personal use"
echo ""
DMG_SIZE=$(ls -lh "${DMG_OUTPUT}" | awk '{print $5}')
echo -e "${GREEN}?? DMG Size: ${DMG_SIZE}${NC}"
echo ""
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
