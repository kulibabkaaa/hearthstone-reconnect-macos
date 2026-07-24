#!/bin/bash
set -euo pipefail

APP="/Applications/HS Reconnect.app"
APP_BINARY="$APP/Contents/MacOS/HSReconnect"
HELPER="/usr/local/libexec/hsreconnect-helper"
SUDOERS="/etc/sudoers.d/hsreconnect"
RECEIPT="io.github.kulibabkaaa.HSReconnect.pkg"
BUNDLE_ID="io.github.kulibabkaaa.HSReconnect"

console_user() {
    /usr/bin/stat -f '%Su' /dev/console
}

validate_user() {
    local user="$1"
    [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] &&
        [[ "$user" != "root" ]] &&
        [[ "$user" != "loginwindow" ]] &&
        [[ "$user" != "_mbsetupuser" ]]
}

if [[ "${1:-}" != "--privileged" ]]; then
    user="$(console_user)"
    if ! validate_user "$user"; then
        echo "HS Reconnect could not identify the signed-in user." >&2
        exit 1
    fi

    if [[ -x "$APP_BINARY" ]]; then
        "$APP_BINARY" --unregister-login-item || true
    fi
    /usr/bin/pkill -x HSReconnectWatcher >/dev/null 2>&1 || true
    /usr/bin/pkill -x HSReconnect >/dev/null 2>&1 || true

    exec /usr/bin/sudo "$0" --privileged "$user"
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "Administrator access is required to uninstall HS Reconnect." >&2
    exit 1
fi

user="${2:-}"
if ! validate_user "$user"; then
    echo "HS Reconnect could not identify the signed-in user." >&2
    exit 1
fi

user_home="$(/usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory |
    /usr/bin/awk '{print $2}')"
if [[ -z "$user_home" || "$user_home" == "/" ]]; then
    echo "HS Reconnect could not locate the user folder." >&2
    exit 1
fi

/bin/rm -f "$HELPER"
/bin/rm -f "$SUDOERS"
/bin/rm -rf "$APP"
/bin/rm -f "$user_home/Library/Preferences/$BUNDLE_ID.plist"
/bin/rm -rf "$user_home/Library/Logs/HS Reconnect"
/usr/sbin/pkgutil --forget "$RECEIPT" >/dev/null 2>&1 || true

echo "HS Reconnect was removed."
