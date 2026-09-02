#!/bin/bash
# Assembles and signs Blip.app.
# Steps: generate Blip.xcodeproj with XcodeGen (only when project.yml changed) -> Release build with xcodebuild
#        -> draw and bundle the app icon -> sign. Xcode takes care of Info.plist and the resource bundles.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Blip"
APP_DIR="${DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
DERIVED_DATA="${DIR}/.build/xcode"

echo "==> xcodegen"
xcodegen generate --spec "${DIR}/project.yml" --project "${DIR}" --use-cache --quiet

echo "==> xcodebuild (release)"
xcodebuild -project "${DIR}/${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DERIVED_DATA}" -quiet build

echo "==> bundle"
rm -rf "${APP_DIR}"
cp -R "${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app" "${APP_DIR}"

# App icon: Scripts/make-icon.swift draws the artwork, which becomes an icns in Resources.
# The black drawing is the bundle icon; the white one (-dark) is for the About panel in dark mode
echo "==> icon"
ICON_WORK="${DIR}/.build/icon"
mkdir -p "${ICON_WORK}"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip.png"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip-dark.png" --dark
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip.png" "${CONTENTS}/Resources/${APP_NAME}.icns"
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip-dark.png" "${CONTENTS}/Resources/${APP_NAME}-dark.icns"

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
