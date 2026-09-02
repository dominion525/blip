#!/bin/bash
# Runs the automated tests for Geometry.swift and DoubleTap.swift. AppKit code is out of scope (checked by hand).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "${OUT}"' EXIT

echo "==> swiftc (tests)"
swiftc -o "${OUT}/blip-tests" "${DIR}/Geometry.swift" "${DIR}/DoubleTap.swift" "${DIR}"/Tests/*.swift

echo "==> run"
"${OUT}/blip-tests"
