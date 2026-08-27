#!/bin/bash
# Purpose: Build disposable native windows for Split View integration checks; no workspace data is read.
# Usage: bash claude_jobs/build-split-view-fixture.sh
# Launch: open "build/testing/Split View Fixture.app"; quit the fixture to close its test windows.
# Signing: Reuse signing.local.json, never create a certificate or fall back to ad-hoc signing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT/build/testing/Split View Fixture.app"
SIGNING_IDENTITY="$(plutil -extract identity raw -expect string "$ROOT/signing.local.json")"
[[ "$SIGNING_IDENTITY" =~ ^[A-F0-9]{40}$ ]]
mkdir -p "$APP_PATH/Contents/MacOS" "$ROOT/.build/tmp" "$ROOT/.build/clang-module-cache"
export TMPDIR="$ROOT/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache"
swiftc -swift-version 6 "$ROOT/Tests/Fixtures/SplitViewFixture.swift" -o "$APP_PATH/Contents/MacOS/SplitViewFixture"
cp "$ROOT/Tests/Fixtures/SplitViewFixture.plist" "$APP_PATH/Contents/Info.plist"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP_PATH"
codesign --verify --strict "$APP_PATH"
printf 'Built test fixture: %s\n' "$APP_PATH"
