#!/bin/zsh
set -euo pipefail

package="${1:?Usage: create-release-dmg.sh PACKAGE OUTPUT_DMG}"
output_dmg="${2:?Usage: create-release-dmg.sh PACKAGE OUTPUT_DMG}"
temporary_dir="$(mktemp -d /private/tmp/hs-reconnect-dmg.XXXXXX)"
image_root="${temporary_dir}/image"
temporary_dmg="${temporary_dir}/HS-Reconnect.dmg"
dmg_identifier="io.github.kulibabkaaa.HSReconnect.dmg"

cleanup() {
  rm -rf -- "${temporary_dir}"
}

trap cleanup EXIT

application_identity="${APPLICATION_SIGNING_IDENTITY:-$(
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1
)}"

[[ -f "${package}" ]] || {
  echo "Installer package not found: ${package}" >&2
  exit 1
}
[[ -n "${application_identity}" ]] || {
  echo "A Developer ID Application identity is required." >&2
  exit 1
}

mkdir -p "${image_root}" "${output_dmg:h}"
ditto --norsrc --noextattr \
  "${package}" \
  "${image_root}/Install HS Reconnect.pkg"

hdiutil create \
  -srcFolder "${image_root}" \
  -volname "HS Reconnect" \
  -format UDZO \
  -o "${temporary_dmg}"

codesign --force \
  --sign "${application_identity}" \
  --timestamp \
  --identifier "${dmg_identifier}" \
  "${temporary_dmg}"

codesign --verify --verbose=2 "${temporary_dmg}"
hdiutil verify "${temporary_dmg}"

rm -f -- "${output_dmg}"
ditto --norsrc --noextattr "${temporary_dmg}" "${output_dmg}"

codesign --verify --verbose=2 "${output_dmg}"
hdiutil verify "${output_dmg}"

echo "${output_dmg}"
