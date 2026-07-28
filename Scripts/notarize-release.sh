#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
version="$(
  awk '/MARKETING_VERSION:/ { gsub(/"/, "", $2); print $2; exit }' \
    "${project_dir}/project.yml"
)"
dmg="${2:-${project_dir}/dist/HS-Reconnect-${version}.dmg}"
profile="${NOTARY_PROFILE:-HSReconnect-Notary}"
mode="${1:-}"

case "${mode}" in
  submit)
    [[ -f "${dmg}" ]] || {
      echo "Disk image not found: ${dmg}" >&2
      exit 1
    }
    xcrun notarytool submit "${dmg}" \
      --keychain-profile "${profile}" \
      --output-format json
    ;;
  finish)
    submission_id="${3:-}"
    [[ -n "${submission_id}" ]] || {
      echo "Provide the notarization submission ID." >&2
      exit 1
    }
    info="$(
      xcrun notarytool info "${submission_id}" \
        --keychain-profile "${profile}" \
        --output-format json
    )"
    print -r -- "${info}"
    status="$(
      print -r -- "${info}" \
        | plutil -extract status raw -o - -
    )"
    [[ "${status}" == "Accepted" ]] || {
      [[ "${status}" == "In Progress" ]] \
        && echo "Apple is still processing the disk image." >&2
      [[ "${status}" != "In Progress" ]] \
        && xcrun notarytool log "${submission_id}" \
          --keychain-profile "${profile}" \
        || true
      exit 1
    }
    xcrun stapler staple "${dmg}"
    xcrun stapler validate "${dmg}"
    spctl --assess \
      --type open \
      --context context:primary-signature \
      --verbose=2 \
      "${dmg}"
    ;;
  *)
    echo "Usage: $0 submit [DMG]" >&2
    echo "       $0 finish [DMG] SUBMISSION_ID" >&2
    exit 1
    ;;
esac
