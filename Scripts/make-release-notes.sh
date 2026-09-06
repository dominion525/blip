#!/bin/bash
# Renders a release's body into the page Sparkle shows in its update dialog.
# Usage: Scripts/make-release-notes.sh <tag> <output.html>
#
# The body is whatever the GitHub release carries at the time this runs, rendered through the
# same Markdown API that renders the release page, so the two never drift in style. The release
# workflow calls this when it publishes; release-notes.yml calls it again whenever the body is
# edited afterwards, which is when the hand-written notes usually arrive.
#
# gh needs a token in GH_TOKEN.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <tag> <output.html>" >&2
  exit 2
fi

TAG="$1"
OUTPUT="$2"
VERSION="${TAG#v}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

gh release view "${TAG}" --json body --jq .body > "${WORK}/body.md"
body="$(gh api /markdown -f mode=gfm -F text=@"${WORK}/body.md")"

mkdir -p "$(dirname "${OUTPUT}")"
{
  printf '<!doctype html>\n<meta charset="utf-8">\n'
  printf '<title>Blip %s</title>\n' "${VERSION}"
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<style>body{font:14px/1.6 -apple-system,system-ui,sans-serif;margin:1em;color:#1d1d1f}'
  printf 'code,pre{font-family:ui-monospace,monospace;background:#f5f5f7;border-radius:4px}'
  printf 'pre{padding:.75em;overflow-x:auto}code{padding:.1em .3em}'
  printf 'h1,h2,h3{line-height:1.3}img{max-width:100%%}'
  printf '@media(prefers-color-scheme:dark){body{background:#1d1d1f;color:#f5f5f7}'
  printf 'code,pre{background:#2c2c2e}}</style>\n'
  printf '%s\n' "${body}"
} > "${OUTPUT}"

echo "wrote ${OUTPUT}"
