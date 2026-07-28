# Releasing HS Reconnect

Version 1.0.0 is distributed directly from GitHub as a notarized installer.

## Requirements

- Xcode and XcodeGen
- Developer ID Application certificate
- Developer ID Installer certificate
- Developer ID provisioning profiles for the host and Network Extension
- A valid `notarytool` Keychain profile named `HSReconnect-Notary`

Signing credentials remain in the macOS Keychain and are never committed.

## Build

```sh
Scripts/build-release.sh
```

The release builder runs all tests, archives the universal app, applies the
Developer ID system-extension entitlements and profiles, creates a fixed-location
installer, and verifies every embedded signature. Xcode 26 requires this manual
Developer ID export step for Network Extension system extensions.

## Notarize

```sh
Scripts/notarize-release.sh submit
Scripts/notarize-release.sh finish \
  dist/HS-Reconnect-1.0.0.pkg SUBMISSION_ID
```

The finish step staples Apple's ticket and verifies Gatekeeper acceptance.

## Verify

```sh
Scripts/verify-release.sh dist/HS-Reconnect-1.0.0.pkg
```

Only the verified, stapled package is attached to the GitHub v1.0.0 release.
