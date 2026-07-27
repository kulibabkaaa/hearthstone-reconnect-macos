#!/bin/bash
set -euo pipefail

APP="/Applications/HS Reconnect.app"
APP_BINARY="$APP/Contents/MacOS/HSReconnect"
WATCHER_BINARY="$APP/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HSReconnectWatcher"
HELPER="/usr/local/libexec/hsreconnect-helper"
SUDOERS="/etc/sudoers.d/hsreconnect"
RECEIPT="io.github.kulibabkaaa.HSReconnect.pkg"
BUNDLE_ID="io.github.kulibabkaaa.HSReconnect"
LEGACY_APP="/Applications/Hearthstone Reconnect.app"
LEGACY_BINARY="$LEGACY_APP/Contents/MacOS/HearthstoneReconnect"
LEGACY_BUNDLE_ID="com.local.HearthstoneReconnect"
DESKTOP_SHORTCUT_NAME="HS Reconnect.app"

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

user_home_for() {
    local user="$1"
    local record user_home

    record="$(
        /usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null ||
            true
    )"
    user_home="${record#*: }"
    if [[ -z "$record" || "$user_home" != /* ||
        "$user_home" == "/" || "$user_home" == *$'\n'* ]]; then
        return 1
    fi
    printf '%s\n' "$user_home"
}

remove_desktop_shortcut() {
    local user="$1"
    local user_home desktop_shortcut existing_target

    user_home="$(user_home_for "$user" || true)"
    [[ -n "$user_home" ]] || return 0
    desktop_shortcut="$user_home/Desktop/$DESKTOP_SHORTCUT_NAME"
    [[ -L "$desktop_shortcut" ]] || return 0
    existing_target="$(
        /usr/bin/readlink "$desktop_shortcut" 2>/dev/null || true
    )"
    if [[ "$existing_target" == "$APP" ]]; then
        /bin/rm -f "$desktop_shortcut"
    fi
}

terminate_exact_executable() {
    local executable="$1"
    local process_name="$2"
    local pid command

    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
        if [[ "$command" == "$executable" ||
            "$command" == "$executable"\ * ]]; then
            /bin/kill -TERM "$pid" 2>/dev/null || true
        fi
    done < <(/usr/bin/pgrep -x "$process_name" 2>/dev/null || true)

    for _ in $(/usr/bin/seq 1 50); do
        /bin/sleep 0.02
        if ! /usr/bin/pgrep -x "$process_name" >/dev/null 2>&1; then
            return
        fi
    done

    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
        if [[ "$command" == "$executable" ||
            "$command" == "$executable"\ * ]]; then
            /bin/kill -KILL "$pid" 2>/dev/null || true
        fi
    done < <(/usr/bin/pgrep -x "$process_name" 2>/dev/null || true)
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
    terminate_exact_executable "$WATCHER_BINARY" "HSReconnectWatcher"
    terminate_exact_executable "$APP_BINARY" "HSReconnect"
    terminate_exact_executable "$LEGACY_BINARY" "HearthstoneReconnect"

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

if [[ -x "$APP_BINARY" ]]; then
    /usr/bin/sudo -H -u "$user" \
        "$APP_BINARY" --unregister-login-item >/dev/null 2>&1 || true
fi
terminate_exact_executable "$WATCHER_BINARY" "HSReconnectWatcher"
terminate_exact_executable "$APP_BINARY" "HSReconnect"
terminate_exact_executable "$LEGACY_BINARY" "HearthstoneReconnect"

remove_desktop_shortcut "$user"
/bin/rm -f "$HELPER"
/bin/rm -f "$SUDOERS"
/bin/rm -rf "$APP"
/bin/rm -rf "$LEGACY_APP"
/usr/bin/sudo -H -u "$user" \
    /usr/bin/defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
/usr/bin/sudo -H -u "$user" \
    /usr/bin/defaults delete "$LEGACY_BUNDLE_ID" >/dev/null 2>&1 || true
/usr/bin/sudo -H -u "$user" \
    /bin/sh -c '/bin/rm -rf "$HOME/Library/Logs/HS Reconnect"'
/usr/sbin/pkgutil --forget "$RECEIPT" >/dev/null 2>&1 || true

echo "HS Reconnect was removed."
