#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PACKAGE="$ROOT/dist/HS-Reconnect-1.0.0.pkg"
PROFILE="${NOTARY_PROFILE:-}"
MODE="${1:-}"

usage() {
    echo "Usage:"
    echo "  NOTARY_PROFILE=PROFILE $0 submit [PACKAGE]"
    echo "  NOTARY_PROFILE=PROFILE $0 finish SUBMISSION_ID [PACKAGE]"
}

if [[ -z "$PROFILE" ]]; then
    echo "Set NOTARY_PROFILE to a Keychain profile created by notarytool." >&2
    exit 64
fi

case "$MODE" in
submit)
    package="${2:-$DEFAULT_PACKAGE}"
    if [[ ! -f "$package" ]]; then
        echo "Package not found: $package" >&2
        exit 66
    fi

    /usr/bin/xcrun notarytool submit "$package" \
        --keychain-profile "$PROFILE" \
        --output-format json
    echo "Save the submission id, then run the finish command after Apple accepts it."
    ;;

finish)
    submission_id="${2:-}"
    package="${3:-$DEFAULT_PACKAGE}"
    if [[ -z "$submission_id" ]]; then
        usage >&2
        exit 64
    fi
    if [[ ! -f "$package" ]]; then
        echo "Package not found: $package" >&2
        exit 66
    fi

    info="$(
        /usr/bin/xcrun notarytool info "$submission_id" \
            --keychain-profile "$PROFILE" \
            --output-format json
    )"
    printf '%s\n' "$info"
    status="$(
        printf '%s' "$info" |
            /usr/bin/plutil -extract status raw -o - -
    )"

    if [[ "$status" == "In Progress" ]]; then
        echo "Apple is still processing this submission." >&2
        exit 75
    fi
    if [[ "$status" != "Accepted" ]]; then
        /usr/bin/xcrun notarytool log "$submission_id" \
            --keychain-profile "$PROFILE" || true
        echo "Apple did not accept this submission." >&2
        exit 1
    fi

    /usr/bin/xcrun stapler staple "$package"
    /usr/bin/xcrun stapler validate "$package"
    /usr/sbin/spctl --assess --type install --verbose=2 "$package"
    echo "$package"
    ;;

*)
    usage >&2
    exit 64
    ;;
esac
