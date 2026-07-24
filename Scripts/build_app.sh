#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${APP_OUTPUT_DIR:-$ROOT/build}"
FINAL_APP="$OUTPUT_DIR/HS Reconnect.app"
STAGING_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hsreconnect-app.XXXXXX")"
APP="$STAGING_ROOT/HS Reconnect.app"
RELEASE="$ROOT/.build/apple/Products/Release"
WATCHER="$APP/Contents/Library/LoginItems/HS Reconnect Watcher.app"
IDENTITY="${APP_SIGNING_IDENTITY:--}"

cleanup() {
    /bin/rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

"$ROOT/Scripts/generate_icon.sh" >/dev/null

cd "$ROOT"
/usr/bin/swift build -c release --arch arm64 --arch x86_64

/bin/rm -rf "$APP"
/bin/mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Resources" \
    "$WATCHER/Contents/MacOS"

/bin/cp "$ROOT/Packaging/HSReconnect-Info.plist" \
    "$APP/Contents/Info.plist"
/bin/cp "$ROOT/Packaging/HSReconnectWatcher-Info.plist" \
    "$WATCHER/Contents/Info.plist"
/usr/bin/install -m 755 "$RELEASE/HSReconnect" \
    "$APP/Contents/MacOS/HSReconnect"
/usr/bin/install -m 755 "$RELEASE/HSReconnectWatcher" \
    "$WATCHER/Contents/MacOS/HSReconnectWatcher"
/usr/bin/install -m 755 "$ROOT/Support/hsreconnect-helper" \
    "$APP/Contents/Resources/hsreconnect-helper"
/usr/bin/install -m 755 "$ROOT/Scripts/uninstall.sh" \
    "$APP/Contents/Resources/uninstall.sh"
/usr/bin/install -m 644 "$ROOT/Support/AppIcon.icns" \
    "$APP/Contents/Resources/AppIcon.icns"

/usr/bin/xattr -cr "$APP"

if [[ "$IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - --options runtime \
        "$WATCHER"
    /usr/bin/codesign --force --sign - --options runtime \
        "$APP"
else
    /usr/bin/codesign --force --sign "$IDENTITY" \
        --options runtime --timestamp "$WATCHER"
    /usr/bin/codesign --force --sign "$IDENTITY" \
        --options runtime --timestamp "$APP"
fi

/usr/bin/xattr -cr "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

/bin/mkdir -p "$OUTPUT_DIR"
/bin/rm -rf "$FINAL_APP"
COPYFILE_DISABLE=1 /usr/bin/ditto "$APP" "$FINAL_APP"
/usr/bin/xattr -cr "$FINAL_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$FINAL_APP"

echo "$FINAL_APP"
