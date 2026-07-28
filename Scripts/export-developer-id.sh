#!/bin/zsh
set -euo pipefail

archive_path="${1:?Usage: export-developer-id.sh ARCHIVE OUTPUT_APP}"
output_app="${2:?Usage: export-developer-id.sh ARCHIVE OUTPUT_APP}"
team_id="D8KUYWS8JN"
host_bundle_id="io.github.kulibabkaaa.HSReconnect"
extension_bundle_id="${host_bundle_id}.ProxyExtension"
profile_dir="${PROVISIONING_PROFILE_DIR:-${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles}"
source_app="${archive_path}/Products/Applications/HS Reconnect.app"
extension_relative_path="Contents/Library/SystemExtensions/${extension_bundle_id}.systemextension"
watcher_relative_path="Contents/Library/LoginItems/HS Reconnect Watcher.app"
temporary_dir="$(mktemp -d /tmp/hs-reconnect-developer-id.XXXXXX)"

cleanup() {
  rm -rf -- "${temporary_dir}"
}

trap cleanup EXIT

application_identity="${APPLICATION_SIGNING_IDENTITY:-$(
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1
)}"

[[ -n "${application_identity}" ]] || {
  echo "A Developer ID Application identity is required." >&2
  exit 1
}

[[ -d "${source_app}" ]] || {
  echo "The Xcode archive does not contain HS Reconnect.app." >&2
  exit 1
}

[[ -d "${profile_dir}" ]] || {
  echo "The Xcode provisioning-profile directory is missing." >&2
  exit 1
}

find_direct_profile() {
  local bundle_id="$1"
  local candidate decoded profile_name application_identifier network_extensions

  for candidate in \
    "${profile_dir}"/*.provisionprofile(N) \
    "${profile_dir}"/*.mobileprovision(N); do
    decoded="${temporary_dir}/profile-$RANDOM.plist"
    if ! security cms -D -i "${candidate}" > "${decoded}" 2>/dev/null; then
      continue
    fi

    profile_name="$(
      /usr/libexec/PlistBuddy -c "Print :Name" "${decoded}" 2>/dev/null \
        || true
    )"
    application_identifier="$(
      /usr/libexec/PlistBuddy \
        -c "Print :Entitlements:com.apple.application-identifier" \
        "${decoded}" 2>/dev/null \
        || true
    )"
    network_extensions="$(
      /usr/libexec/PlistBuddy \
        -c "Print :Entitlements:com.apple.developer.networking.networkextension" \
        "${decoded}" 2>/dev/null \
        || true
    )"

    if [[ "${profile_name}" == *"Direct"* ]] \
      && [[ "${application_identifier}" == "${team_id}.${bundle_id}" ]] \
      && [[ "${network_extensions}" == *"app-proxy-provider-systemextension"* ]]; then
      print -r -- "${candidate}"
      return 0
    fi
  done

  echo "No Developer ID provisioning profile was found for ${bundle_id}." >&2
  return 1
}

host_profile="$(find_direct_profile "${host_bundle_id}")"
extension_profile="$(find_direct_profile "${extension_bundle_id}")"

rm -rf -- "${output_app}"
mkdir -p "${output_app:h}"
ditto --norsrc --noextattr "${source_app}" "${output_app}"
xattr -cr "${output_app}"

extension_path="${output_app}/${extension_relative_path}"
watcher_path="${output_app}/${watcher_relative_path}"
host_entitlements="${temporary_dir}/host-entitlements.plist"
extension_entitlements="${temporary_dir}/extension-entitlements.plist"

[[ -d "${extension_path}" ]] || {
  echo "The archived Network Extension is missing." >&2
  exit 1
}
[[ -d "${watcher_path}" ]] || {
  echo "The archived Hearthstone watcher is missing." >&2
  exit 1
}

codesign -d --entitlements "${host_entitlements}" --xml \
  "${output_app}" 2>/dev/null
codesign -d --entitlements "${extension_entitlements}" --xml \
  "${extension_path}" 2>/dev/null

/usr/libexec/PlistBuddy \
  -c "Set :com.apple.developer.networking.networkextension:0 app-proxy-provider-systemextension" \
  "${host_entitlements}"
/usr/libexec/PlistBuddy \
  -c "Set :com.apple.developer.networking.networkextension:0 app-proxy-provider-systemextension" \
  "${extension_entitlements}"
/usr/libexec/PlistBuddy \
  -c "Delete :com.apple.security.get-task-allow" \
  "${host_entitlements}" 2>/dev/null || true
/usr/libexec/PlistBuddy \
  -c "Delete :com.apple.security.get-task-allow" \
  "${extension_entitlements}" 2>/dev/null || true

ditto --norsrc --noextattr \
  "${host_profile}" \
  "${output_app}/Contents/embedded.provisionprofile"
ditto --norsrc --noextattr \
  "${extension_profile}" \
  "${extension_path}/Contents/embedded.provisionprofile"

codesign --force \
  --sign "${application_identity}" \
  --options runtime \
  --timestamp \
  "${watcher_path}"
codesign --force \
  --sign "${application_identity}" \
  --options runtime \
  --timestamp \
  --entitlements "${extension_entitlements}" \
  "${extension_path}"
codesign --force \
  --sign "${application_identity}" \
  --options runtime \
  --timestamp \
  --entitlements "${host_entitlements}" \
  "${output_app}"

codesign --verify --deep --strict --verbose=2 "${output_app}"

for signed_path in "${watcher_path}" "${extension_path}" "${output_app}"; do
  codesign -dv --verbose=4 "${signed_path}" 2>&1 \
    | grep "Authority=Developer ID Application:" >/dev/null
done

for signed_path in "${extension_path}" "${output_app}"; do
  codesign -d --entitlements - "${signed_path}" 2>&1 \
    | grep "app-proxy-provider-systemextension" >/dev/null
done

echo "${output_app}"
