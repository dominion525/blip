#!/bin/bash
# Assembles Blip.app with a direct swiftc invocation and signs it ad hoc
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Blip"
BUNDLE_ID="local.blip"
VERSION="0.1.0"
MIN_MACOS="13.0"
ARCH="$(uname -m)"

APP_DIR="${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

echo "==> swiftc (${ARCH}, macOS ${MIN_MACOS}+)"
swiftc -O \
  -target "${ARCH}-apple-macos${MIN_MACOS}" \
  -o "${MACOS_DIR}/${APP_NAME}" \
  Geometry.swift DoubleTap.swift main.swift

echo "==> Info.plist"
cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --sign - "${APP_DIR}"

echo "==> done: ${APP_DIR}"
