#!/bin/bash
# Runs every test: BlipCore with swift test, the app (BlipTests) through the Xcode project.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> swift test (BlipCore)"
swift test --package-path "${DIR}"

echo "==> xcodegen"
xcodegen generate --spec "${DIR}/project.yml" --project "${DIR}" --use-cache --quiet

echo "==> xcodebuild test (Blip)"
xcodebuild -project "${DIR}/Blip.xcodeproj" -scheme Blip -configuration Debug -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DIR}/.build/xcode" -quiet test
