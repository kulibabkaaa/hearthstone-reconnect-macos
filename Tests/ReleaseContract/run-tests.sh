#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h:h}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f "${project_dir}/project.yml" ]] \
  || fail "project.yml is missing"
[[ -f "${project_dir}/Scripts/build-release.sh" ]] \
  || fail "the public release builder is missing"
[[ -f "${project_dir}/Scripts/export-developer-id.sh" ]] \
  || fail "the Developer ID system-extension exporter is missing"
[[ -f "${project_dir}/Scripts/create-release-dmg.sh" ]] \
  || fail "the signed GitHub Release DMG builder is missing"
[[ -f "${project_dir}/Scripts/verify-dmg-contents.sh" ]] \
  || fail "the release DMG content verifier is missing"
[[ -f "${project_dir}/Extension/ProxyExtension.entitlements" ]] \
  || fail "the transparent-proxy extension is missing"
[[ -f "${project_dir}/Scripts/Installer/postinstall" ]] \
  || fail "the installer postinstall script is missing"
[[ -f "${project_dir}/Scripts/Installer/preinstall" ]] \
  || fail "the installer preinstall script is missing"

version="$(
  /usr/bin/awk '
    /MARKETING_VERSION:/ {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' "${project_dir}/project.yml"
)"

[[ -n "${version}" ]] || fail "the release version is missing"

readme_download_url="releases/latest/download/HS-Reconnect-${version}.dmg"
/usr/bin/head -n 40 "${project_dir}/README.md" \
  | /usr/bin/grep -Fq "${readme_download_url}" \
  || fail "the README must put the current direct download near the top"

/usr/bin/grep -Fq \
  "dist/HS-Reconnect-${version}.dmg" \
  "${project_dir}/Documentation/RELEASING.md" \
  || fail "release instructions do not match the current version"

/usr/bin/grep -q \
  'PRODUCT_BUNDLE_IDENTIFIER: io.github.kulibabkaaa.HSReconnect$' \
  "${project_dir}/project.yml" \
  || fail "the host bundle identifier is not final"

/usr/bin/grep -q \
  'PRODUCT_BUNDLE_IDENTIFIER: io.github.kulibabkaaa.HSReconnect.ProxyExtension$' \
  "${project_dir}/project.yml" \
  || fail "the extension bundle identifier is not final"

if /usr/bin/grep -R -n \
  --exclude-dir=.build \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.git \
  --exclude='run-tests.sh' \
  'HS Reconnect Proxy\|HSReconnectProxyPrototype' \
  "${project_dir}/App" \
  "${project_dir}/Extension" \
  "${project_dir}/Watcher" \
  "${project_dir}/README.md" \
  "${project_dir}/project.yml"; then
  fail "prototype branding remains in the public product"
fi

if /usr/bin/grep -q \
  'hsreconnect-helper\|sudoers' \
  "${project_dir}/README.md"; then
  fail "the public documentation still describes the retired helper"
fi

prepare_proxy_block="$(
  /usr/bin/awk '
    /private func prepareProxy\(\)/ { in_prepare = 1 }
    in_prepare && /private func activationFailureMessage\(\)/ { exit }
    in_prepare { print }
  ' "${project_dir}/App/AppDelegate.swift"
)"

if /usr/bin/grep -q \
  'beginUninstallCleanup' \
  <<< "${prepare_proxy_block}"; then
  fail "normal proxy activation can still start uninstall cleanup"
fi

/usr/bin/grep -q \
  'ProcessInfo.processInfo.processIdentifier' \
  "${project_dir}/App/AppUninstaller.swift" \
  || fail "self-removal does not wait for the uninstall process to exit"

/usr/bin/grep -q \
  'AppUninstallRecoveryPolicy.shouldRestoreRuntime' \
  "${project_dir}/App/AppDelegate.swift" \
  || fail "failed cleanup can still reactivate a removed extension"

/usr/bin/grep -q \
  'SMAppService.openSystemSettingsLoginItems' \
  "${project_dir}/App/AppDelegate.swift" \
  || fail "approval guidance cannot reopen the correct System Settings pane"

/usr/bin/grep -q \
  'setSystemExtensionApprovalRequired(true)' \
  "${project_dir}/App/AppDelegate.swift" \
  || fail "approval guidance is not kept available in the app window"

scheme_build_block="$(
  /usr/bin/awk '
    /^    build:$/ { in_build = 1 }
    in_build && /^    test:$/ { exit }
    in_build { print }
  ' "${project_dir}/project.yml"
)"

if /usr/bin/grep -q \
  'ProxyCoreTests\|ProxyCore: test' \
  <<< "${scheme_build_block}"; then
  fail "the archive build action still includes unit-test products"
fi

if /usr/bin/grep -q \
  'xcodebuild -exportArchive' \
  "${project_dir}/Scripts/build-release.sh"; then
  fail "Xcode 26 cannot directly export this Developer ID system extension"
fi

/usr/bin/grep -q \
  'app-proxy-provider-systemextension' \
  "${project_dir}/Scripts/export-developer-id.sh" \
  || fail "the Developer ID exporter does not apply direct-distribution entitlements"

/usr/bin/grep -q \
  'embedded.provisionprofile' \
  "${project_dir}/Scripts/export-developer-id.sh" \
  || fail "the Developer ID exporter does not embed distribution profiles"

/usr/bin/grep -q \
  '/private/tmp/hs-reconnect-release' \
  "${project_dir}/Scripts/build-release.sh" \
  || fail "release signing still runs inside file-provider managed storage"

/usr/bin/grep -q \
  'create-release-dmg.sh' \
  "${project_dir}/Scripts/build-release.sh" \
  || fail "the release build does not create the downloadable DMG"

/usr/bin/grep -q \
  'hdiutil create' \
  "${project_dir}/Scripts/create-release-dmg.sh" \
  || fail "the DMG builder does not create a disk image"

/usr/bin/grep -q \
  -- '-format UDZO' \
  "${project_dir}/Scripts/create-release-dmg.sh" \
  || fail "the release DMG must use Apple's read-only UDZO format"

/usr/bin/grep -q \
  'io.github.kulibabkaaa.HSReconnect.dmg' \
  "${project_dir}/Scripts/create-release-dmg.sh" \
  || fail "the release DMG does not have a unique signing identifier"

/usr/bin/grep -q \
  'verify-dmg-contents.sh' \
  "${project_dir}/Scripts/build-release.sh" \
  || fail "the release build does not inspect the completed DMG"

/usr/bin/grep -q \
  'HS-Reconnect-${version}.dmg' \
  "${project_dir}/Scripts/notarize-release.sh" \
  || fail "notarization does not target the outer release DMG"

/usr/bin/grep -q \
  'download_count' \
  "${project_dir}/README.md" \
  || fail "the privacy-preserving GitHub download count is not documented"

if /usr/bin/grep -Eq \
  '^[[:space:]]*status=' \
  "${project_dir}/Scripts/notarize-release.sh"; then
  fail "the notarization script assigns zsh's read-only status variable"
fi

echo "Release identity tests passed."
