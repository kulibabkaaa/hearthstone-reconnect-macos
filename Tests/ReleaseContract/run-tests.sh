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
[[ -f "${project_dir}/Extension/ProxyExtension.entitlements" ]] \
  || fail "the transparent-proxy extension is missing"
[[ -f "${project_dir}/Scripts/Installer/postinstall" ]] \
  || fail "the installer postinstall script is missing"

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

echo "Release identity tests passed."
