#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/MongrelCalculator"
BUILD_DIR="$ROOT_DIR/.build/beta"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="MongrelCalculator.app"
ARCHIVE_NAME="MongrelCalculator-0.9.1-beta.1-macOS-universal.zip"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

command -v xcodegen >/dev/null || {
    print -u2 "xcodegen is required. Install it with: brew install xcodegen"
    exit 1
}

rm -rf "$BUILD_DIR"
mkdir -p "$DIST_DIR"

(
    cd "$PROJECT_DIR"
    xcodegen generate
    xcodebuild \
        -project MongrelCalculator.xcodeproj \
        -scheme MongrelCalculator \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$BUILD_DIR" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGNING_ALLOWED=NO \
        -quiet \
        build
)

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
ZIP_PATH="$DIST_DIR/$ARCHIVE_NAME"

test -d "$APP_PATH" || {
    print -u2 "Expected app was not produced at: $APP_PATH"
    exit 1
}

if [[ -n "$NOTARY_PROFILE" && -z "$SIGNING_IDENTITY" ]]; then
    print -u2 "NOTARYTOOL_PROFILE requires DEVELOPER_ID_APPLICATION."
    exit 1
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$APP_PATH"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ZIP="$BUILD_DIR/MongrelCalculator-notary.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
fi

rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(
    cd "$DIST_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

if [[ -n "$NOTARY_PROFILE" ]]; then
    print "Built signed and notarized beta:"
elif [[ -n "$SIGNING_IDENTITY" ]]; then
    print "Built Developer ID signed beta (not notarized):"
else
    print "Built unsigned beta:"
fi
print "  $ZIP_PATH"
print "  $ZIP_PATH.sha256"

if [[ -z "$NOTARY_PROFILE" ]]; then
    print
    print "Public downloads should be Developer ID signed and notarized."
fi
