#!/bin/bash
# Builds Blip-<version>.dmg from Blip.app with create-dmg (brew install create-dmg).
#
# Run build.sh first, and notarize.sh before this one: the app is copied into the image as it is,
# so it has to carry its own stapled ticket. The image itself is notarized separately, by running
# notarize.sh again against the dmg this writes.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"

APP_NAME="Blip"
APP_DIR="${DIR}/${APP_NAME}.app"
WORK="${DIR}/.build/dmg"
STAGING="${WORK}/staging"
BACKGROUND="${WORK}/background.png"

if [ ! -d "${APP_DIR}" ]; then
  echo "${APP_NAME}.app not found. Run build.sh first." >&2
  exit 1
fi

if ! command -v create-dmg > /dev/null; then
  echo "create-dmg not found. Install it with: brew install create-dmg" >&2
  exit 1
fi

VERSION="$(awk '/MARKETING_VERSION:/ { gsub(/"/, "", $2); print $2 }' "${DIR}/project.yml")"
if [ -z "${VERSION}" ]; then
  echo "MARKETING_VERSION not found in project.yml" >&2
  exit 1
fi
DMG="${DIR}/${APP_NAME}-${VERSION}.dmg"

# Same rule as build.sh: CODESIGN_IDENTITY if set, else a Developer ID Application certificate from
# the keychain if present, else leave the image unsigned. Signing the image is not required for
# notarization, but there is no reason to leave it off when a certificate is available.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY="Developer ID Application"
fi

echo "==> background"
mkdir -p "${WORK}"
swift "${DIR}/Scripts/make-dmg-background.swift" "${BACKGROUND}"

# create-dmg copies everything in the source folder, so the staging holds the app and nothing else.
# The Applications folder comes from --app-drop-link.
echo "==> staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"

# The window geometry has to agree with make-dmg-background.swift, which draws the arrow between
# the two icon centers.
echo "==> create-dmg"
rm -f "${DMG}"
CREATE_DMG_ARGS=(
  --volname "${APP_NAME}"
  --volicon "${APP_DIR}/Contents/Resources/${APP_NAME}.icns"
  --background "${BACKGROUND}"
  --window-pos 200 120
  --window-size 660 400
  --icon-size 128
  --icon "${APP_NAME}.app" 165 190
  --hide-extension "${APP_NAME}.app"
  --app-drop-link 495 190
)
create-dmg "${CREATE_DMG_ARGS[@]}" "${DMG}" "${STAGING}"

# Signed here rather than through create-dmg's --codesign, which derives the identifier from the
# file name and lands on "Blip-0". The identifier is cosmetic for an image, but name it properly.
if [ -n "${IDENTITY}" ]; then
  echo "==> codesign (${IDENTITY})"
  codesign --force --timestamp --sign "${IDENTITY}" --identifier "com.dominion525.blip.dmg" "${DMG}"
else
  echo "==> codesign skipped: no Developer ID Application certificate and no CODESIGN_IDENTITY"
fi

echo "==> done: ${DMG}"
