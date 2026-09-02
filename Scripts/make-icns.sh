#!/bin/bash
# Builds an icns from a 1024x1024 PNG.
# Usage: Scripts/make-icns.sh <input PNG> <output icns>
set -euo pipefail

INPUT="$1"
OUTPUT="$2"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

ICONSET="${WORK}/Blip.iconset"
mkdir -p "${ICONSET}"

# File names and sizes iconutil expects
for entry in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x 128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 512:icon_256x256@2x 512:icon_512x512 1024:icon_512x512@2x; do
  px="${entry%%:*}"
  name="${entry##*:}"
  sips -z "${px}" "${px}" "${INPUT}" --out "${ICONSET}/${name}.png" > /dev/null
done

iconutil -c icns "${ICONSET}" -o "${OUTPUT}"
