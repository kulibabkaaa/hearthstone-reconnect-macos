#!/bin/zsh
set -euo pipefail

user_home="${1:?user home is required}"
user_name="${2:?user name is required}"
app_path="${3:-/Applications/HS Reconnect.app}"
desktop_dir="${user_home}/Desktop"
shortcut_path="${desktop_dir}/HS Reconnect.app"

[[ -d "${app_path}" ]] || exit 0

mkdir -p "${desktop_dir}"

if [[ -L "${shortcut_path}" ]]; then
  [[ "$(readlink "${shortcut_path}")" == "${app_path}" ]] && exit 0
  exit 0
fi

[[ -e "${shortcut_path}" ]] && exit 0

ln -s "${app_path}" "${shortcut_path}"

if [[ "$(id -u)" == "0" ]]; then
  chown -h "${user_name}" "${shortcut_path}"
fi
