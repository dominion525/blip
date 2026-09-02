#!/bin/bash
# Assembles Blip.app from the swift build products and signs it ad hoc
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Blip"
BUNDLE_ID="local.blip"
VERSION="0.1.0"
MIN_MACOS="13.0"

APP_DIR="${DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

echo "==> swift build (release)"
swift build -c release --package-path "${DIR}"
BIN_PATH="$(swift build -c release --package-path "${DIR}" --show-bin-path)"

echo "==> bundle"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Copy the SwiftPM resource bundles (library strings and so on) into Resources; without them Bundle.module crashes
mkdir -p "${CONTENTS}/Resources"
for bundle in "${BIN_PATH}"/*.bundle; do
  [ -d "${bundle}" ] || continue
  cp -R "${bundle}" "${CONTENTS}/Resources/"
done

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
  <key>NSHumanReadableCopyright</key>
  <string>Blip</string>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --sign - "${APP_DIR}"

echo "==> done: ${APP_DIR}"
