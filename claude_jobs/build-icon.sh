#!/bin/bash
# Purpose: Export the approved PNG artwork to a complete macOS .icns file.
# Usage: bash claude_jobs/build-icon.sh
# Input: App/Assets/AppIcon.png. Output: App/Assets/AppIcon.icns.
# Uses only macOS sips and iconutil; intermediate sizes stay in .build/AppIcon.iconset.
set -euo pipefail

if [[ $# -ne 0 ]]; then
    printf 'Usage: bash claude_jobs/build-icon.sh\n' >&2
    exit 64
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/App/Assets/AppIcon.png"
ICONSET="$ROOT/.build/AppIcon.iconset"

if [[ ! -s "$SOURCE" ]]; then
    printf 'Missing app icon source: %s\n' "$SOURCE" >&2
    exit 1
fi

mkdir -p "$ICONSET" "$ROOT/.build/tmp"
export TMPDIR="$ROOT/.build/tmp"

for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ROOT/App/Assets/AppIcon.icns"
printf 'Built: %s\n' "$ROOT/App/Assets/AppIcon.icns"
