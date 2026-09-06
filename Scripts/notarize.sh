#!/bin/bash
# Submits a target to the Apple notary service and staples the ticket to it.
# Usage: Scripts/notarize.sh [target]   (default: Blip.app)
#
# The target is either the app bundle or a disk image. The notary service takes an archive rather
# than a bundle, so a bundle is zipped for the submission; a disk image is submitted as it is.
# Run build.sh before notarizing the app, and make-dmg.sh before notarizing the image.
#
# Credentials come from the environment:
#   NOTARY_KEYCHAIN_PROFILE  a profile stored by `xcrun notarytool store-credentials`
#   NOTARY_KEY_P8            path to an App Store Connect API key, with NOTARY_KEY_ID and NOTARY_ISSUER_ID
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${DIR}/Blip.app}"

if [ ! -e "${TARGET}" ]; then
  echo "${TARGET} not found. Run build.sh for the app, or make-dmg.sh for the image." >&2
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

case "${TARGET}" in
  *.app)
    # The ticket is stapled to the app itself, so this archive is only for the submission;
    # package the stapled app separately.
    SUBMISSION="${DIR}/.build/notarize/$(basename "${TARGET%.app}").zip"
    echo "==> archive for submission"
    mkdir -p "$(dirname "${SUBMISSION}")"
    rm -f "${SUBMISSION}"
    ditto -c -k --keepParent "${TARGET}" "${SUBMISSION}"
    # Gatekeeper assesses the app as something to execute
    ASSESS=(-t exec)
    ;;
  *.dmg)
    SUBMISSION="${TARGET}"
    # Gatekeeper assesses the image as something to open, against the image's own signature
    ASSESS=(-t open --context context:primary-signature)
    ;;
  *)
    echo "Unsupported target: ${TARGET}. Pass an .app bundle or a .dmg." >&2
    exit 1
    ;;
esac

echo "==> notarytool submit"
xcrun notarytool submit "${SUBMISSION}" "${CREDENTIALS[@]}" --wait

echo "==> stapler staple"
xcrun stapler staple "${TARGET}"
xcrun stapler validate "${TARGET}"
spctl -a -vvv "${ASSESS[@]}" "${TARGET}"

echo "==> done: ${TARGET}"
