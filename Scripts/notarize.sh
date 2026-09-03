#!/bin/bash
# Submits Blip.app to the Apple notary service and staples the ticket to it.
# Run build.sh first; the app has to be signed with a Developer ID certificate.
#
# Credentials come from the environment:
#   NOTARY_KEYCHAIN_PROFILE  a profile stored by `xcrun notarytool store-credentials`
#   NOTARY_KEY_P8            path to an App Store Connect API key, with NOTARY_KEY_ID and NOTARY_ISSUER_ID
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${DIR}/Blip.app"
ZIP="${DIR}/.build/notarize/Blip.zip"

if [ ! -d "${APP_DIR}" ]; then
  echo "Blip.app not found. Run build.sh first." >&2
  exit 1
fi

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  CREDENTIALS=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
elif [ -n "${NOTARY_KEY_P8:-}" ]; then
  CREDENTIALS=(--key "${NOTARY_KEY_P8}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER_ID}")
else
  echo "No notary credentials. Set NOTARY_KEYCHAIN_PROFILE, or NOTARY_KEY_P8 with NOTARY_KEY_ID and NOTARY_ISSUER_ID." >&2
  exit 1
fi

# The notary service takes an archive, not a bundle. The ticket is stapled to the app itself,
# so this archive is only for the submission; package the stapled app separately.
echo "==> archive for submission"
mkdir -p "$(dirname "${ZIP}")"
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

echo "==> notarytool submit"
xcrun notarytool submit "${ZIP}" "${CREDENTIALS[@]}" --wait

echo "==> stapler staple"
xcrun stapler staple "${APP_DIR}"
xcrun stapler validate "${APP_DIR}"
spctl -a -vvv -t exec "${APP_DIR}"

echo "==> done: ${APP_DIR}"
