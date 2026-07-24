#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hsreconnect-verify.XXXXXX")"
APP="$VERIFY_ROOT/HS Reconnect.app"
PACKAGE="$VERIFY_ROOT/HS-Reconnect-1.0.0.pkg"
EXPANDED_PACKAGE="$VERIFY_ROOT/expanded-package"
MAIN="$APP/Contents/MacOS/HSReconnect"
WATCHER="$APP/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HSReconnectWatcher"

cleanup() {
    /bin/rm -rf "$VERIFY_ROOT"
}
trap cleanup EXIT

cd "$ROOT"
/usr/bin/swift test
for script in \
    "$ROOT"/Scripts/*.sh \
    "$ROOT/Support/hsreconnect-helper" \
    "$ROOT/Packaging/scripts/postinstall"; do
    /bin/bash -n "$script"
done

APP_OUTPUT_DIR="$VERIFY_ROOT" "$ROOT/Scripts/build_app.sh" >/dev/null
PACKAGE_OUTPUT_DIR="$VERIFY_ROOT" \
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

/usr/sbin/pkgutil --expand-full "$PACKAGE" "$EXPANDED_PACKAGE"
PACKAGED_APP="$(
    /usr/bin/find "$EXPANDED_PACKAGE" -type d \
        -name "HS Reconnect.app" -print -quit
)"
if [[ -z "$PACKAGED_APP" ]]; then
    echo "The installer package does not contain HS Reconnect.app." >&2
    exit 1
fi
PACKAGED_MAIN="$PACKAGED_APP/Contents/MacOS/HSReconnect"
PACKAGED_WATCHER="$PACKAGED_APP/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HSReconnectWatcher"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$PACKAGED_APP"
/usr/bin/lipo "$PACKAGED_MAIN" -verify_arch arm64 x86_64
/usr/bin/lipo "$PACKAGED_WATCHER" -verify_arch arm64 x86_64
/usr/bin/cmp -s \
    "$ROOT/Support/hsreconnect-helper" \
    "$PACKAGED_APP/Contents/Resources/hsreconnect-helper"

if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
    /usr/sbin/pkgutil --check-signature "$PACKAGE"
else
    /usr/sbin/pkgutil --check-signature "$PACKAGE" || true
fi

if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" \
    "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    echo "Unexpected URL scheme found." >&2
    exit 1
fi

echo "Release verification passed without running a reconnect."
