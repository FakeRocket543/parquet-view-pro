#!/bin/bash
set -e

APP_NAME="Parquet View Pro"
APP_FILE="${APP_NAME}.app"
VERSION="1.2.0"
BUILD_DIR=".build/arm64-apple-macosx/release"
DMG_NAME="ParquetViewPro-v${VERSION}.dmg"
BINARY="Parquet-View"

echo "🔨 Building app bundle..."

# Clean and create app bundle structure
rm -rf "${APP_FILE}"
mkdir -p "${APP_FILE}/Contents/MacOS"
mkdir -p "${APP_FILE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${BINARY}" "${APP_FILE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "Parquet Viewer/Info.plist" "${APP_FILE}/Contents/Info.plist"

# Set permissions
chmod +x "${APP_FILE}/Contents/MacOS/${APP_NAME}"

echo "📦 Creating DMG..."

# Create temporary DMG directory
DMG_TEMP_DIR=".dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temporary directory
cp -R "${APP_FILE}" "${DMG_TEMP_DIR}/"

# Create Applications symbolic link
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
               -srcfolder "${DMG_TEMP_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_NAME}"

# Clean up
rm -rf "${DMG_TEMP_DIR}"

# Generate SHA256
shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256"

echo "✅ Done! Created: ${DMG_NAME}"
echo "SHA256: $(cat ${DMG_NAME}.sha256)"
