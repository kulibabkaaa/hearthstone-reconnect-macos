#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hsreconnect-package.XXXXXX")"
PAYLOAD_ROOT="$STAGING_ROOT/payload"
APP="$PAYLOAD_ROOT/HS Reconnect.app"
PACKAGE_DIR="$STAGING_ROOT/package"
COMPONENT="$PACKAGE_DIR/HSReconnect-component.pkg"
OUTPUT_DIR="$ROOT/dist"
OUTPUT="$OUTPUT_DIR/HS-Reconnect-1.0.0.pkg"
IDENTITY="${INSTALLER_SIGNING_IDENTITY:-}"

cleanup() {
    /bin/rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

/bin/mkdir -p "$PAYLOAD_ROOT" "$PACKAGE_DIR" "$OUTPUT_DIR"
APP_OUTPUT_DIR="$PAYLOAD_ROOT" "$ROOT/Scripts/build_app.sh" >/dev/null

COPYFILE_DISABLE=1 /usr/bin/pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --install-location "/Applications" \
    --component-plist "$ROOT/Packaging/HSReconnect-component.plist" \
    --scripts "$ROOT/Packaging/scripts" \
    --identifier "io.github.kulibabkaaa.HSReconnect.pkg" \
    --version "1.0.0" \
    --min-os-version "13.0" \
    --ownership recommended \
    "$COMPONENT"

if [[ -n "$IDENTITY" ]]; then
    /usr/bin/productbuild --package "$COMPONENT" \
        --sign "$IDENTITY" "$OUTPUT"
else
    /usr/bin/productbuild --package "$COMPONENT" "$OUTPUT"
fi

echo "$OUTPUT"
