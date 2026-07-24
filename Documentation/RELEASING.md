# Releasing HS Reconnect

Version 1.0.0 is a manual release. Do not publish it until the live reconnect
test has passed.

## Prerequisites

- Xcode command-line tools
- Developer ID Application certificate in the login Keychain
- Developer ID Installer certificate in the login Keychain
- Apple Developer Team ID `77D9QAT65X`
- A `notarytool` Keychain profile

Signing credentials stay in the macOS Keychain. They are not stored in this
repository.

Create the notary profile once:

```sh
xcrun notarytool store-credentials "HSReconnect-Notary" \
  --apple-id "APPLE_ID" \
  --team-id "77D9QAT65X"
```

Enter the app-specific password when prompted. Do not put it in a script or
commit it.

## Test

Run the source and release checks without triggering a reconnect:

```sh
Scripts/verify_release.sh
```

Then test the installer, app launch, shortcut recording, menu, Hearthstone
auto-open setting, and uninstaller on both Apple silicon and Intel hardware or
clean virtual machines.

The final live reconnect test is performed manually by the project owner.

## Sign and package

Find the exact certificate names:

```sh
security find-identity -v -p codesigning
security find-identity -v -p basic
```

Build the signed package:

```sh
APP_SIGNING_IDENTITY="Developer ID Application: NAME (77D9QAT65X)" \
INSTALLER_SIGNING_IDENTITY="Developer ID Installer: NAME (77D9QAT65X)" \
Scripts/build_package.sh
```

Verify that `pkgutil --check-signature` reports the expected Developer ID
Installer identity.

## Notarize

```sh
NOTARY_PROFILE="HSReconnect-Notary" \
Scripts/notarize.sh dist/HS-Reconnect-1.0.0.pkg
```

The script submits the package, waits for Apple, staples the ticket, validates
it, and runs Gatekeeper's installer assessment.

## Draft release

1. Confirm `swift test` and the GitHub `tests` check pass.
2. Confirm the signed and notarized package installs only on macOS 13 or later.
3. Confirm the installed helper matches the helper embedded in the app.
4. Complete the project owner's live reconnect test.
5. Attach `dist/HS-Reconnect-1.0.0.pkg` to the existing draft GitHub release.
6. Publish the draft only after all checks pass.
