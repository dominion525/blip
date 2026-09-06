#!/bin/bash
# Assembles and signs Blip.app.
# Steps: generate Blip.xcodeproj with XcodeGen -> Release build with xcodebuild
#        -> draw and bundle the app icon -> sign. Xcode takes care of Info.plist and the resource bundles.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Blip"
APP_DIR="${DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
DERIVED_DATA="${DIR}/.build/xcode"

echo "==> xcodegen"
xcodegen generate --spec "${DIR}/project.yml" --project "${DIR}" --quiet

echo "==> xcodebuild (release)"
xcodebuild -project "${DIR}/${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DERIVED_DATA}" -quiet build

echo "==> bundle"
rm -rf "${APP_DIR}"
cp -R "${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app" "${APP_DIR}"

# App icon: Scripts/make-icon.swift draws the artwork, which becomes an icns in Resources.
# The black drawing on a light gray plate is the bundle icon. The About panel uses the plain drawing on a transparent background,
# black (-about) in light mode and white (-about-dark) in dark mode
echo "==> icon"
ICON_WORK="${DIR}/.build/icon"
mkdir -p "${ICON_WORK}"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip.png" --plate=E6E6E8
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip-about.png"
swift "${DIR}/Scripts/make-icon.swift" "${ICON_WORK}/Blip-about-dark.png" --dark
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip.png" "${CONTENTS}/Resources/${APP_NAME}.icns"
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip-about.png" "${CONTENTS}/Resources/${APP_NAME}-about.icns"
"${DIR}/Scripts/make-icns.sh" "${ICON_WORK}/Blip-about-dark.png" "${CONTENTS}/Resources/${APP_NAME}-about-dark.icns"

# Signing: CODESIGN_IDENTITY if set, else a Developer ID Application certificate from the Keychain if present, else ad hoc.
# An ad hoc signature changes on every rebuild, which can reset permissions such as Input Monitoring; a certificate keeps the app identity stable.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY="Developer ID Application"
fi
if [ -n "${IDENTITY}" ]; then
  SIGN=(--force --options runtime --timestamp --sign "${IDENTITY}")
  echo "==> codesign (${IDENTITY})"
else
  SIGN=(--force --sign -)
  echo "==> codesign (ad-hoc)"
fi

# Sparkle carries its own executables, and macOS wants each of them signed in its own right.
# Signed from the inside out, in the order Sparkle documents; --deep is explicitly not the way.
# Downloader.xpc keeps its entitlements because it runs sandboxed.
SPARKLE="${CONTENTS}/Frameworks/Sparkle.framework"
if [ -d "${SPARKLE}" ]; then
  SPARKLE_VERSION="${SPARKLE}/Versions/B"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/XPCServices/Installer.xpc"
  codesign "${SIGN[@]}" --preserve-metadata=entitlements "${SPARKLE_VERSION}/XPCServices/Downloader.xpc"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/Autoupdate"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/Updater.app"
  codesign "${SIGN[@]}" "${SPARKLE}"
else
  echo "    Sparkle.framework not found in the bundle; skipping its signatures" >&2
fi

codesign "${SIGN[@]}" "${APP_DIR}"

echo "==> done: ${APP_DIR}"
