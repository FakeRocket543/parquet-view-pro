#!/bin/bash
set -e

# ============================================================
#  Parquet View Pro — Signed & Notarized DMG Builder
# ============================================================
#
#  前置需求：
#    1. Apple Developer 帳號 + "Developer ID Application" 憑證已安裝
#    2. 在 appleid.apple.com 產生 App-Specific Password
#    3. 填好下面三個變數
#
#  用法：
#    ./build_signed_dmg.sh
#
# ============================================================

# ===== 請填入你的資訊 =====
DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"  # security find-identity -v 的輸出
APPLE_ID="<your-apple-id-email>"
TEAM_ID="<your-team-id>"
APP_PASSWORD="<app-specific-password>"  # appleid.apple.com → Sign-In and Security → App-Specific Passwords
# ==========================

APP_NAME="Parquet View Pro"
BUNDLE_ID="com.parquetview.pro"
VERSION="1.4.1"
BUILD_DIR=".build/arm64-apple-macosx/release"
BINARY="Parquet-View"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="ParquetViewPro-v${VERSION}.dmg"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${YELLOW}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# --- 1. 檢查憑證 ---
step "1/7 檢查簽名憑證"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || fail "找不到 Developer ID Application 憑證，請先安裝"
ok "憑證存在"

# --- 2. Release build ---
step "2/7 編譯 Release"
swift build -c release
[ -f "${BUILD_DIR}/${BINARY}" ] || fail "找不到執行檔"
ok "編譯完成"

# --- 3. 建立 .app bundle ---
step "3/7 建立 .app bundle"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Parquet Viewer/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# 確保 Info.plist 有 CFBundleIdentifier
/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleExecutable" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

# SPM resource bundle carries the localized strings
if [ -d "${BUILD_DIR}/ParquetViewerSwift_ParquetViewLib.bundle" ]; then
    cp -R "${BUILD_DIR}/ParquetViewerSwift_ParquetViewLib.bundle" "${APP_BUNDLE}/Contents/Resources/"
else
    err "SPM resource bundle missing — localization will fall back to raw keys"
fi
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

ok ".app bundle 建立完成"

# --- 4. Code Sign ---
step "4/7 簽名 .app"
xattr -cr "${APP_BUNDLE}"

codesign --force --deep --timestamp \
  --options runtime \
  --sign "${DEVELOPER_ID}" \
  "${APP_BUNDLE}"

# 驗證簽名
codesign --verify --verbose=2 "${APP_BUNDLE}" || fail "簽名驗證失敗"
ok "簽名完成並驗證通過"

# --- 5. 建立 DMG ---
step "5/7 建立 DMG"
DMG_TEMP=".dmg_temp_signed"
rm -rf "${DMG_TEMP}" "${DMG_NAME}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${DMG_TEMP}" \
  -ov -format UDZO \
  "${DMG_NAME}"

rm -rf "${DMG_TEMP}"

# 簽名 DMG 本身
codesign --force --timestamp --sign "${DEVELOPER_ID}" "${DMG_NAME}"
ok "DMG 建立並簽名完成"

# --- 6. 公證 (Notarize) ---
step "6/7 提交公證（需要幾分鐘）"
xcrun notarytool submit "${DMG_NAME}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${TEAM_ID}" \
  --password "${APP_PASSWORD}" \
  --wait

# 檢查公證結果
xcrun notarytool log "${DMG_NAME}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${TEAM_ID}" \
  --password "${APP_PASSWORD}" 2>/dev/null || true

ok "公證完成"

# --- 7. 釘票 (Staple) ---
step "7/7 釘票 (Staple)"
xcrun stapler staple "${DMG_NAME}"
ok "釘票完成"

# --- 完成 ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ 簽名 + 公證 + 釘票 全部完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
shasum -a 256 "${DMG_NAME}" | tee "${DMG_NAME}.sha256"
echo ""

# 最終驗證
echo "最終驗證："
spctl --assess --type open --context context:primary-signature -v "${DMG_NAME}" 2>&1 || true
echo ""
echo "使用者下載後可以直接雙擊安裝，Gatekeeper 不會擋。"
