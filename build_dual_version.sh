#!/bin/bash

# Parquet View - Dual Version Build Script
# Builds both Standard and Pro editions

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_CONFIG_FILE="${PROJECT_DIR}/Parquet Viewer/BuildConfig.swift"

echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${BLUE}   Parquet View - Dual Version Build${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo ""

# Function to set build edition
set_build_edition() {
    local edition=$1
    echo -e "${YELLOW}??  Setting build edition to: ${edition}${NC}"
    
    # Replace the CURRENT_EDITION line in BuildConfig.swift
    if [ "$edition" = "standard" ]; then
        sed -i '' 's/let CURRENT_EDITION: BuildEdition = .pro/let CURRENT_EDITION: BuildEdition = .standard/' "$BUILD_CONFIG_FILE"
        sed -i '' 's/let CURRENT_EDITION: BuildEdition = .standard/let CURRENT_EDITION: BuildEdition = .standard/' "$BUILD_CONFIG_FILE"
    else
        sed -i '' 's/let CURRENT_EDITION: BuildEdition = .standard/let CURRENT_EDITION: BuildEdition = .pro/' "$BUILD_CONFIG_FILE"
        sed -i '' 's/let CURRENT_EDITION: BuildEdition = .pro/let CURRENT_EDITION: BuildEdition = .pro/' "$BUILD_CONFIG_FILE"
    fi
    
    echo -e "${GREEN}? Edition set to ${edition}${NC}"
}

# Function to build and package
build_and_package() {
    local edition=$1
    local app_name=$2
    local dmg_name=$3
    
    echo ""
    echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
    echo -e "${BLUE}   Building ${app_name}${NC}"
    echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
    echo ""
    
    # Set edition
    set_build_edition "$edition"
    
    # Clean
    echo -e "${YELLOW}??  Step 1: Cleaning...${NC}"
    rm -rf "${PROJECT_DIR}/.build/release"
    swift package clean
    echo -e "${GREEN}? Clean complete${NC}"
    echo ""
    
    # Build
    echo -e "${YELLOW}??  Step 2: Building release...${NC}"
    swift build -c release
    echo -e "${GREEN}? Build complete${NC}"
    echo ""
    
    # Create .app bundle
    echo -e "${YELLOW}??  Step 3: Creating .app bundle...${NC}"
    
    local BUILD_DIR="${PROJECT_DIR}/.build/release"
    local APP_BUNDLE="${BUILD_DIR}/${app_name}.app"
    local BUNDLE_ID="com.parquetview.$(echo $edition | tr '[:upper:]' '[:lower:]')"
    
    mkdir -p "${APP_BUNDLE}/Contents/MacOS"
    mkdir -p "${APP_BUNDLE}/Contents/Resources"
    
    cp "${BUILD_DIR}/Parquet-View" "${APP_BUNDLE}/Contents/MacOS/${app_name}"
    
    # Create Info.plist
    cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${app_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundleDisplayName</key>
    <string>${app_name}</string>
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
    
    if [ -f "${PROJECT_DIR}/assets/AppIcon.icns" ]; then
        cp "${PROJECT_DIR}/assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    fi
    
    echo -e "${GREEN}? App bundle created${NC}"
    echo ""
    
    # Sign
    echo -e "${YELLOW}??  Step 4: Signing app...${NC}"
    xattr -cr "${APP_BUNDLE}"
    codesign --force --deep --sign - "${APP_BUNDLE}"
    echo -e "${GREEN}? App signed${NC}"
    echo ""
    
    # Create DMG
    echo -e "${YELLOW}??  Step 5: Creating DMG...${NC}"
    
    local TEMP_DMG_DIR="${PROJECT_DIR}/.dmg_temp_${edition}"
    local DMG_OUTPUT="${PROJECT_DIR}/${dmg_name}.dmg"
    
    mkdir -p "${TEMP_DMG_DIR}"
    cp -R "${APP_BUNDLE}" "${TEMP_DMG_DIR}/"
    ln -s /Applications "${TEMP_DMG_DIR}/Applications"
    
    rm -f "${DMG_OUTPUT}"
    hdiutil create -volname "${app_name}" \
                   -srcfolder "${TEMP_DMG_DIR}" \
                   -ov \
                   -format UDZO \
                   "${DMG_OUTPUT}"
    
    rm -rf "${TEMP_DMG_DIR}"
    
    echo -e "${GREEN}? DMG created${NC}"
    echo ""
    
    # Checksum
    echo -e "${YELLOW}??  Step 6: Generating checksum...${NC}"
    local CHECKSUM=$(shasum -a 256 "${DMG_OUTPUT}" | awk '{print $1}')
    echo "${CHECKSUM}  ${dmg_name}.dmg" > "${DMG_OUTPUT}.sha256"
    echo -e "${GREEN}? Checksum: ${CHECKSUM}${NC}"
    echo ""
    
    local DMG_SIZE=$(ls -lh "${DMG_OUTPUT}" | awk '{print $5}')
    echo -e "${GREEN}?? ${app_name} DMG Size: ${DMG_SIZE}${NC}"
    echo ""
}

# Build Standard Edition
build_and_package "standard" "Parquet View" "ParquetView"

# Build Pro Edition
build_and_package "pro" "Parquet View Pro" "ParquetViewPro"

# Final summary
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo -e "${GREEN}? Dual Version Build Complete!${NC}"
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
echo ""
echo -e "${GREEN}?? Standard Edition:${NC}"
echo -e "   DMG: ${PROJECT_DIR}/ParquetView.dmg"
echo -e "   SHA256: ${PROJECT_DIR}/ParquetView.dmg.sha256"
echo ""
echo -e "${GREEN}?? Pro Edition (with Tabs):${NC}"
echo -e "   DMG: ${PROJECT_DIR}/ParquetViewPro.dmg"
echo -e "   SHA256: ${PROJECT_DIR}/ParquetViewPro.dmg.sha256"
echo ""
echo -e "${GREEN}?? Features Comparison:${NC}"
echo -e "   Standard: Basic viewing, export, search"
echo -e "   Pro: All Standard features + Tab support (up to 20 tabs)"
echo ""
echo -e "${BLUE}????????????????????????????????????????????????????????????${NC}"
