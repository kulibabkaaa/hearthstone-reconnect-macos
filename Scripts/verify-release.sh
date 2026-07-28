#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
version="$(
  awk '/MARKETING_VERSION:/ { gsub(/"/, "", $2); print $2; exit }' \
    "${project_dir}/project.yml"
)"
package="${1:-${project_dir}/dist/HS-Reconnect-${version}.pkg}"
inspection_dir="$(mktemp -d /tmp/hs-reconnect-release.XXXXXX)"

cleanup() {
  rm -rf -- "${inspection_dir}"
}

trap cleanup EXIT

swift test --package-path "${project_dir}"
"${project_dir}/Tests/Packaging/run-tests.sh"
"${project_dir}/Tests/ReleaseContract/run-tests.sh"

zsh -n \
  "${project_dir}"/Scripts/*.sh \
  "${project_dir}"/Scripts/Installer/*

pkgutil --check-signature "${package}"
pkgutil --expand-full "${package}" "${inspection_dir}/package"
"${project_dir}/Scripts/verify-expanded-installer.sh" \
  "${inspection_dir}/package"

app="${inspection_dir}/package/Payload/Applications/HS Reconnect.app"
codesign --verify --deep --strict --verbose=2 "${app}"
codesign -dv --verbose=4 "${app}" 2>&1 \
  | grep "Authority=Developer ID Application:" >/dev/null

lipo "${app}/Contents/MacOS/HS Reconnect" \
  -verify_arch arm64 x86_64
lipo \
  "${app}/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HS Reconnect Watcher" \
  -verify_arch arm64 x86_64
lipo \
  "${app}/Contents/Library/SystemExtensions/io.github.kulibabkaaa.HSReconnect.ProxyExtension.systemextension/Contents/MacOS/io.github.kulibabkaaa.HSReconnect.ProxyExtension" \
  -verify_arch arm64 x86_64

xcrun stapler validate "${package}"
spctl --assess --type install --verbose=2 "${package}"

echo "Release verification passed."
