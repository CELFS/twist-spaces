#!/bin/bash
# Purpose: Build a local Twist Spaces.app with the system Swift toolchain, without dependencies.
# Usage: bash claude_jobs/build-app.sh [debug|release] (default: debug).
# Output: build/<configuration>/Twist Spaces.app; no installation, launch, or Git changes.
# Signing: Use the fixed identity in signing.local.json; never fall back to ad-hoc signing.
# Version: Read version.json and write its values into the generated app's Info.plist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
if [[ $# -gt 1 || ( "$CONFIGURATION" != debug && "$CONFIGURATION" != release ) ]]; then
    printf 'Usage: bash claude_jobs/build-app.sh [debug|release]\n' >&2
    exit 64
fi

# Validate before compiling; never substitute or automatically increment a version.
VERSION_FILE="$ROOT/version.json"
if [[ ! -f "$VERSION_FILE" ]]; then
    printf 'Missing version configuration: %s\n' "$VERSION_FILE" >&2
    exit 1
fi
if ! APP_VERSION="$(plutil -extract version raw -expect string "$VERSION_FILE")"; then
    printf 'Invalid version.json: "version" must be a string.\n' >&2
    exit 1
fi
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Invalid version.json: "version" must use three numeric components, such as 0.1.0.\n' >&2
    exit 1
fi
if ! APP_BUILD="$(plutil -extract build raw -expect integer "$VERSION_FILE")"; then
    printf 'Invalid version.json: "build" must be an integer.\n' >&2
    exit 1
fi
if [[ ! "$APP_BUILD" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid version.json: "build" must be a positive integer.\n' >&2
    exit 1
fi

SIGNING_FILE="$ROOT/signing.local.json"
if [[ ! -f "$SIGNING_FILE" ]]; then
    printf 'Missing local signing configuration. Run once: bash claude_jobs/setup-local-signing.sh\n' >&2
    exit 1
fi
if ! SIGNING_IDENTITY="$(plutil -extract identity raw -expect string "$SIGNING_FILE")"; then
    printf 'Invalid signing.local.json: "identity" must be a certificate fingerprint.\n' >&2
    exit 1
fi
if [[ ! "$SIGNING_IDENTITY" =~ ^[A-F0-9]{40}$ ]]; then
    printf 'Invalid signing.local.json: expected a 40-character certificate SHA-1 fingerprint.\n' >&2
    exit 1
fi
VALID_IDENTITIES="$(security find-identity -v -p codesigning)"
if ! printf '%s\n' "$VALID_IDENTITIES" | awk -v identity="$SIGNING_IDENTITY" '$2 == identity { found=1 } END { exit !found }'; then
    printf 'The configured signing identity is unavailable. Unlock or restore the original login keychain identity; no ad-hoc fallback is used.\n' >&2
    exit 1
fi

if [[ ! -s "$ROOT/App/Assets/AppIcon.icns" ]]; then
    printf 'Missing app icon. Run: bash claude_jobs/build-icon.sh\n' >&2
    exit 1
fi

# Reject incomplete UI resources before replacing the existing app bundle.
for LOGO_RESOURCE in AppLogo.png AppLogoWhiteMask.png; do
    if [[ ! -s "$ROOT/Sources/TwistSpaces/Resources/$LOGO_RESOURCE" ]]; then
        printf 'Missing required logo resource: %s\n' "$LOGO_RESOURCE" >&2
        exit 1
    fi
done

BUILD_OPTIONS=(
    --package-path "$ROOT"
    --scratch-path "$ROOT/.build"
    --cache-path "$ROOT/.build/cache"
    --config-path "$ROOT/.build/config"
    --security-path "$ROOT/.build/security"
    --manifest-cache local
    --configuration "$CONFIGURATION"
)

mkdir -p "$ROOT/.build/clang-module-cache" "$ROOT/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache"
export TMPDIR="$ROOT/.build/tmp"

swift build "${BUILD_OPTIONS[@]}" --product TwistSpaces
BIN_PATH="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
APP_PATH="$ROOT/build/$CONFIGURATION/Twist Spaces.app"
RESOURCE_BUNDLE="$BIN_PATH/TwistSpaces_TwistSpaces.bundle"

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    printf 'Missing Swift resource bundle: %s\n' "$RESOURCE_BUNDLE" >&2
    exit 1
fi

for LOGO_RESOURCE in AppLogo.png AppLogoWhiteMask.png; do
    if [[ ! -s "$RESOURCE_BUNDLE/$LOGO_RESOURCE" ]]; then
        printf 'Required logo was not packaged: %s\n' "$LOGO_RESOURCE" >&2
        exit 1
    fi
done

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/TwistSpaces" "$APP_PATH/Contents/MacOS/TwistSpaces"
cp "$ROOT/App/Info.plist" "$APP_PATH/Contents/Info.plist"
# Only the generated bundle is updated; the source plist has no duplicate version values.
plutil -insert CFBundleShortVersionString -string "$APP_VERSION" "$APP_PATH/Contents/Info.plist"
plutil -insert CFBundleVersion -string "$APP_BUILD" "$APP_PATH/Contents/Info.plist"
cp "$ROOT/App/Assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
# Packaged apps resolve resources from Contents/Resources, independently of SwiftPM's build cache.
ditto "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/TwistSpaces_TwistSpaces.bundle"
plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none --identifier local.twist-spaces "$APP_PATH"
codesign --verify --strict "$APP_PATH"
printf 'Built: %s\n' "$APP_PATH"
printf 'Version: %s (build %s)\n' "$APP_VERSION" "$APP_BUILD"
printf 'Signing identity: %s\n' "$SIGNING_IDENTITY"
