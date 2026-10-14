#!/bin/bash
set -e

# ============================================================
#  Parquet View Pro — Signed & Notarized DMG Builder
# ============================================================
#
#  前置需求：
#    1. Apple Developer 帳號 + "Developer ID Application" 憑證已安裝
#       （本機：security find-identity -v -p codesigning 可見）
#    2. 公證憑證三選一（優先順序如下）：
#       a. NOTARY_PROFILE — keychain profile
#          （本機現成：yabomish-notary；需先 security unlock-keychain）
#       b. APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
#       c. ASC_PRIVATE_KEY (.p8) + ASC_KEY_ID + ASC_ISSUER_ID
#
#  用法：
#    ./build_signed_dmg.sh
#    NOTARY_PROFILE=yabomish-notary ./build_signed_dmg.sh
#    APPLE_ID=x@y APPLE_APP_SPECIFIC_PASSWORD=xxxx APPLE_TEAM_ID=XXX ./build_signed_dmg.sh
#
# ============================================================

# ===== 簽名身分（與 yabomish 共用同一張 Developer ID）=====
: "${DEVELOPER_ID:=Developer ID Application: CHIH HSIAN LIN (2SYA986D7H)}"

# ===== 公證憑證（預設走 keychain profile；本機已有 yabomish-notary）=====
: "${NOTARY_PROFILE:=yabomish-notary}"
# 以下三個只有在不用 NOTARY_PROFILE / ASC key 時才需要：
: "${APPLE_ID:=}"
: "${APPLE_APP_SPECIFIC_PASSWORD:=}"
: "${APPLE_TEAM_ID:=2SYA986D7H}"
: "${ASC_PRIVATE_KEY:=}"
: "${ASC_KEY_ID:=}"
: "${ASC_ISSUER_ID:=}"
# ==========================

APP_NAME="Parquet View Pro"
BUNDLE_ID="com.parquetview.pro"
VERSION="1.4.2"
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
security find-identity -v -p codesigning | grep "Developer ID Application" | head -2
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

# 確保 Info.plist有關鍵欄位（版本跟腳本 VERSION 走）
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
    echo -e "${RED}WARNING: SPM resource bundle missing — localization will fall back to raw keys${NC}" >&2
fi
# App icon (matches CFBundleIconFile=AppIcon in Info.plist)
if [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
else
    echo -e "${RED}WARNING: assets/AppIcon.icns missing -- app will have no icon" >&2
fi
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

ok ".app bundle 建立完成"

# --- 4. Code Sign ---
step "4/7 簽名 .app"
xattr -cr "${APP_BUNDLE}"

codesign --force --deep --timestamp \
  --options runtime \
  --entitlements "ParquetViewer.entitlements" \
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
NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE}" ]; then
    echo "使用 keychain profile: ${NOTARY_PROFILE}"
    NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE}")
elif [ -n "${ASC_PRIVATE_KEY}" ] && [ -n "${ASC_KEY_ID}" ] && [ -n "${ASC_ISSUER_ID}" ]; then
    echo "使用 App Store Connect API key"
    if [ -f "${ASC_PRIVATE_KEY}" ]; then
        NOTARY_ARGS=(--key "${ASC_PRIVATE_KEY}" --key-id "${ASC_KEY_ID}" --issuer "${ASC_ISSUER_ID}")
    else
        TMP_KEY=$(mktemp -t asc_key)
        chmod 600 "${TMP_KEY}"
        printf '%s\n' "${ASC_PRIVATE_KEY}" > "${TMP_KEY}"
        trap 'rm -f "${TMP_KEY}"' EXIT
        NOTARY_ARGS=(--key "${TMP_KEY}" --key-id "${ASC_KEY_ID}" --issuer "${ASC_ISSUER_ID}")
    fi
elif [ -n "${APPLE_ID}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD}" ]; then
    echo "使用 Apple ID + app-specific password"
    NOTARY_ARGS=(--apple-id "${APPLE_ID}" --password "${APPLE_APP_SPECIFIC_PASSWORD}" --team-id "${APPLE_TEAM_ID}")
else
    fail "沒有公證憑證。設 NOTARY_PROFILE，或 APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD，或 ASC_* 三件套"
fi

xcrun notarytool submit "${DMG_NAME}" "${NOTARY_ARGS[@]}" --wait

ok "公證完成"

# --- 7. 釘票 (Staple) ---
step "7/7 釘票 (Staple)"
xcrun stapler staple "${DMG_NAME}"
xcrun stapler validate "${DMG_NAME}"
ok "釘票完成"

# --- 完成 ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  簽名 + 公證 + 釘票 全部完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
shasum -a 256 "${DMG_NAME}" | tee "${DMG_NAME}.sha256"
echo ""

# 最終驗收：掛載 DMG，驗裡面的 .app（直接驗 .dmg 本體會 rejected，是正常的）
echo "最終驗收："
MNT=$(hdiutil attach -nobrowse -quiet "${DMG_NAME}" | tail -1 | awk -F'\t' '{print $NF}' | sed 's/^ *//')
if [ -n "${MNT}" ]; then
    spctl --assess -vv "${MNT}/${APP_BUNDLE}" 2>&1 || true
    hdiutil detach -quiet "${MNT}" || true
else
    echo "WARNING: 無法掛載 DMG 做最終驗收，請手動驗"
fi
echo ""
echo "上傳到 GitHub release："
echo "  gh release create v${VERSION} \"${DMG_NAME}\" \"${DMG_NAME}.sha256\" --title \"v${VERSION}\" --notes-file docs/release-notes/RELEASE_NOTES_v${VERSION}.md"
