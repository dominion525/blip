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
# Tell the OS which languages are supported; the per-app language setting looks at Contents/Resources/*.lproj
for lang in en ja; do
  mkdir -p "${CONTENTS}/Resources/${lang}.lproj"
done

# App icon: Scripts/make-icon.swift draws the artwork, which becomes an icns in Resources.
# The black drawing is the bundle icon; the white one (-dark) is for the About panel in dark mode
echo "==> icon"
ICON_WORK="${DIR}/.build/icon"
mkdir -p "${ICON_WORK}"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip.png"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip-dark.png" --dark
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip.png" "${CONTENTS}/Resources/${APP_NAME}.icns"
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip-dark.png" "${CONTENTS}/Resources/${APP_NAME}-dark.icns"

echo "==> Info.plist"
cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>ja</string>
  </array>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
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

# Signing: CODESIGN_IDENTITY if set, else a Developer ID Application certificate from the Keychain if present, else ad hoc.
# An ad hoc signature changes on every rebuild, which can reset permissions such as Input Monitoring; a certificate keeps the app identity stable.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY="Developer ID Application"
fi
if [ -n "${IDENTITY}" ]; then
  echo "==> codesign (${IDENTITY})"
  codesign --force --options runtime --timestamp --sign "${IDENTITY}" "${APP_DIR}"
else
  echo "==> codesign (ad-hoc)"
  codesign --force --sign - "${APP_DIR}"
fi

echo "==> done: ${APP_DIR}"
