#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
version="$(
  awk '/MARKETING_VERSION:/ { gsub(/"/, "", $2); print $2; exit }' \
    "${project_dir}/project.yml"
)"
build_root="${HS_RECONNECT_BUILD_ROOT:-/private/tmp/hs-reconnect-release-${UID}}"
archive_path="${build_root}/HS Reconnect.xcarchive"
export_path="${build_root}/export"
payload_root="${build_root}/payload"
package_scripts="${build_root}/installer-scripts"
expanded_package="${build_root}/expanded-package"
output_dir="${project_dir}/dist"
output_package="${output_dir}/HS-Reconnect-${version}.pkg"
output_dmg="${output_dir}/HS-Reconnect-${version}.dmg"
exported_app="${export_path}/HS Reconnect.app"

installer_identity="${INSTALLER_SIGNING_IDENTITY:-$(
  security find-identity -v \
    | sed -n 's/.*"\(Developer ID Installer:[^"]*\)".*/\1/p' \
    | head -n 1
)}"

[[ -n "${installer_identity}" ]] || {
  echo "A Developer ID Installer identity is required." >&2
  exit 1
}

cd "${project_dir}"

xcodegen generate
"${script_dir}/verify-system-extension-config.sh"
swift test
"${project_dir}/Tests/Packaging/run-tests.sh"
"${project_dir}/Tests/ReleaseContract/run-tests.sh"

rm -rf -- "${build_root}"
mkdir -p \
  "${build_root}" \
  "${output_dir}" \
  "${payload_root}/Applications" \
  "${package_scripts}"

xcodebuild archive \
  -project HSReconnect.xcodeproj \
  -scheme HSReconnect \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${archive_path}" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

"${script_dir}/export-developer-id.sh" \
  "${archive_path}" \
  "${exported_app}"

[[ -d "${exported_app}" ]] || {
  echo "Xcode did not export HS Reconnect.app." >&2
  exit 1
}

xattr -cr "${exported_app}"
codesign --verify --deep --strict --verbose=2 "${exported_app}"
codesign -dv --verbose=4 "${exported_app}" 2>&1 \
  | grep "Authority=Developer ID Application:" >/dev/null

if codesign -d --entitlements - "${exported_app}" 2>&1 \
  | grep "com.apple.security.get-task-allow" >/dev/null; then
  echo "Release app contains get-task-allow." >&2
  exit 1
fi

lipo \
  "${exported_app}/Contents/MacOS/HS Reconnect" \
  -verify_arch arm64 x86_64
lipo \
  "${exported_app}/Contents/Library/LoginItems/HS Reconnect Watcher.app/Contents/MacOS/HS Reconnect Watcher" \
  -verify_arch arm64 x86_64
lipo \
  "${exported_app}/Contents/Library/SystemExtensions/io.github.kulibabkaaa.HSReconnect.ProxyExtension.systemextension/Contents/MacOS/io.github.kulibabkaaa.HSReconnect.ProxyExtension" \
  -verify_arch arm64 x86_64

ditto --norsrc --noextattr \
  "${exported_app}" \
  "${payload_root}/Applications/HS Reconnect.app"
ditto --norsrc --noextattr \
  "${script_dir}/Installer/postinstall" \
  "${package_scripts}/postinstall"
ditto --norsrc --noextattr \
  "${script_dir}/Installer/create-desktop-shortcut.sh" \
  "${package_scripts}/create-desktop-shortcut.sh"
chmod 755 \
  "${package_scripts}/postinstall" \
  "${package_scripts}/create-desktop-shortcut.sh"

pkgbuild \
  --analyze \
  --root "${payload_root}" \
  "${build_root}/components.plist"
"${script_dir}/prepare-component-plist.sh" \
  "${build_root}/components.plist"

rm -f -- "${output_package}"
pkgbuild \
  --root "${payload_root}" \
  --component-plist "${build_root}/components.plist" \
  --scripts "${package_scripts}" \
  --install-location / \
  --identifier io.github.kulibabkaaa.HSReconnect.installer \
  --version "${version}" \
  --min-os-version 13.0 \
  --ownership recommended \
  --sign "${installer_identity}" \
  "${output_package}"

pkgutil --check-signature "${output_package}"
pkgutil --expand-full "${output_package}" "${expanded_package}"
"${script_dir}/verify-expanded-installer.sh" \
  "${expanded_package}"
codesign --verify --deep --strict --verbose=2 \
  "${expanded_package}/Payload/Applications/HS Reconnect.app"

"${script_dir}/create-release-dmg.sh" \
  "${output_package}" \
  "${output_dmg}"
"${script_dir}/verify-dmg-contents.sh" \
  "${output_dmg}"

echo "${output_dmg}"
