#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="${1:-$ROOT/dist/HS-Reconnect-1.0.0.pkg}"
PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Set NOTARY_PROFILE to a Keychain profile created by notarytool." >&2
    exit 64
fi

if [[ ! -f "$PACKAGE" ]]; then
    echo "Package not found: $PACKAGE" >&2
    exit 66
fi

/usr/bin/xcrun notarytool submit "$PACKAGE" \
    --keychain-profile "$PROFILE" \
    --wait
/usr/bin/xcrun stapler staple "$PACKAGE"
/usr/bin/xcrun stapler validate "$PACKAGE"
/usr/sbin/spctl --assess --type install --verbose=2 "$PACKAGE"

echo "$PACKAGE"
