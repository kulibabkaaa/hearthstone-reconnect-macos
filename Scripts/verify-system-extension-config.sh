#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
host_entitlements="${project_dir}/App/HSReconnect.entitlements"
extension_entitlements="${project_dir}/Extension/ProxyExtension.entitlements"
extension_info="${project_dir}/Extension/Info.plist"
expected_group='$(TeamIdentifierPrefix)io.github.kulibabkaaa.HSReconnect'
expected_service="${expected_group}.ProxyExtension"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print ${2}" "${1}" 2>/dev/null
}

host_group="$(plist_value "${host_entitlements}" ':com.apple.security.application-groups:0')" || {
  echo "Host app is missing the shared App Group entitlement." >&2
  exit 1
}

extension_group="$(plist_value "${extension_entitlements}" ':com.apple.security.application-groups:0')" || {
  echo "Proxy extension is missing the shared App Group entitlement." >&2
  exit 1
}

mach_service="$(plist_value "${extension_info}" ':NetworkExtension:NEMachServiceName')" || {
  echo "Proxy extension is missing NEMachServiceName." >&2
  exit 1
}

if [[ "${host_group}" != "${expected_group}" ]]; then
  echo "Host App Group does not match the expected release group." >&2
  exit 1
fi

if [[ "${extension_group}" != "${host_group}" ]]; then
  echo "Host and proxy extension App Groups do not match." >&2
  exit 1
fi

if [[ "${mach_service}" != "${expected_service}" ]]; then
  echo "NEMachServiceName is not a child of the shared App Group." >&2
  exit 1
fi

echo "System-extension configuration is valid."
