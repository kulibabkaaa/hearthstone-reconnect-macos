<p align="center">
  <img src="Support/AppIconSource.png" width="128" alt="HS Reconnect icon">
</p>

# HS Reconnect

HS Reconnect is a small macOS utility for native Hearthstone Battlegrounds.
Press the global shortcut to trigger a reconnect. The default shortcut is
Command-Shift-W, and it can be changed in the app.

## Requirements

- macOS 13 or later
- Apple silicon or Intel Mac
- The native macOS version of Hearthstone

## Install

1. Download `HS-Reconnect-1.0.0.pkg` from the latest GitHub release.
2. Open the package and approve the installation.
3. Open HS Reconnect once from Applications.
4. Leave **Open HS Reconnect with Hearthstone** checked if you want the app to
   start quietly when Hearthstone opens.

The installer also creates an HS Reconnect shortcut on the current user's
Desktop. The app shows both a menu bar icon and a Dock icon by default. Turn
off **Show HS Reconnect in Dock** if you want to use only the menu bar icon.
The menu contains **Reconnect**, **Open Window**, and **Quit**.

## What the installer adds

The installer places the app in `/Applications` for all users. It also installs
a root-owned helper at `/usr/local/libexec/hsreconnect-helper` and a narrowly
scoped sudo rule at `/etc/sudoers.d/hsreconnect` for the signed-in console user.
It adds a Desktop shortcut for that user without replacing an existing Desktop
item with the same name.

The helper verifies the running native Hearthstone process and its current game
connection before applying a short, targeted network reset. HS Reconnect refuses
to use an installed helper that differs from the copy inside the app.

## Privacy

HS Reconnect has no analytics, telemetry, advertising, or remote crash service.
Local diagnostic logs redact network addresses and are removed after seven
days. See [PRIVACY.md](PRIVACY.md).

## Uninstall

Open Terminal and run:

```sh
"/Applications/HS Reconnect.app/Contents/Resources/uninstall.sh"
```

The uninstaller asks for administrator approval, then removes the app, its
Desktop shortcut, helper, sudo rule, local logs, preferences, and package
receipt.

## Build from source

```sh
swift test
Scripts/build_app.sh
Scripts/build_package.sh
```

Local builds are ad-hoc signed. A public release must be signed with Developer
ID Application and Developer ID Installer certificates, notarized, stapled, and
verified. The complete process is in
[Documentation/RELEASING.md](Documentation/RELEASING.md).

## Support

Email `kulibabagood@gmail.com`.

## Disclaimer

HS Reconnect is unofficial and is not affiliated with, endorsed by, or
sponsored by Blizzard Entertainment. Use it at your own risk. Game behavior and
policies may change, which may cause HS Reconnect to stop working or become
unsuitable for use.

HS Reconnect is free software released under the [MIT License](LICENSE).
