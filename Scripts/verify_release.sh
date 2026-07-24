#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hsreconnect-verify.XXXXXX")"
APP="$VERIFY_ROOT/HS Reconnect.app"
PACKAGE="$ROOT/dist/HS-Reconnect-1.0.0.pkg"
MAIN="$APP/Contents/MacOS/HSReconnect"
WATCHER="$APP/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HSReconnectWatcher"

cleanup() {
    /bin/rm -rf "$VERIFY_ROOT"
}
trap cleanup EXIT

cd "$ROOT"
/usr/bin/swift test
/bin/bash -n "$ROOT/Support/hsreconnect-helper"
/bin/bash -n "$ROOT/Scripts/uninstall.sh"
/bin/bash -n "$ROOT/Packaging/scripts/postinstall"

APP_OUTPUT_DIR="$VERIFY_ROOT" "$ROOT/Scripts/build_app.sh" >/dev/null
"$ROOT/Scripts/build_package.sh" >/dev/null

/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/plutil -lint \
    "$APP/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/Info.plist"
/usr/bin/xattr -cr "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
if /usr/bin/codesign -d --entitlements - "$APP" 2>&1 |
    /usr/bin/grep -q "get-task-allow"; then
    echo "Release app contains the development get-task-allow entitlement." >&2
    exit 1
fi
/usr/bin/lipo "$MAIN" -verify_arch arm64 x86_64
/usr/bin/lipo "$WATCHER" -verify_arch arm64 x86_64
/usr/bin/cmp -s \
    "$ROOT/Support/hsreconnect-helper" \
    "$APP/Contents/Resources/hsreconnect-helper"
/usr/sbin/pkgutil --check-signature "$PACKAGE" || true

if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" \
    "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    echo "Unexpected URL scheme found." >&2
    exit 1
fi

echo "Release verification passed without running a reconnect."
