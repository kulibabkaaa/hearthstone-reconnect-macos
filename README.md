<p align="center">
  <img src="Support/AppIconSource.png" width="128" alt="HS Reconnect icon">
</p>

# HS Reconnect

HS Reconnect is a small macOS utility for native Hearthstone Battlegrounds.
Press the global shortcut to trigger an immediate reconnect. The default is
Command-Shift-W, and it can be changed in the app.

## Requirements

- macOS 13 or later
- Apple silicon or Intel Mac
- The native macOS version of Hearthstone

## Install

1. Download `HS-Reconnect-1.0.0.pkg` from the latest GitHub release.
2. Open the installer and approve the installation.
3. Open HS Reconnect from Applications or its Desktop shortcut.
4. Approve the system extension and network configuration if macOS asks.
5. Leave **Open HS Reconnect with Hearthstone** checked if you want it to
   start quietly with the game.

The app shows a menu bar icon and a Dock icon by default. Turn off
**Show HS Reconnect in Dock** if you prefer menu-bar-only operation.

## How it works

HS Reconnect uses a local macOS Network Extension that passes native
Hearthstone game traffic through unchanged. When you reconnect, it closes only
the current Hearthstone game connection so the game reconnects immediately.

There is no root helper, sudo rule, traffic redirection, analytics, advertising,
or project server.

## Privacy

HS Reconnect does not collect or transmit personal data. See
[PRIVACY.md](PRIVACY.md).

## Remove

1. Turn off **Open HS Reconnect with Hearthstone** and quit the app.
2. Move the Desktop shortcut and `/Applications/HS Reconnect.app` to Trash.
3. If macOS still shows the extension, remove HS Reconnect under **System
   Settings → General → Login Items & Extensions → Network Extensions**.

## Build from source

The project requires Xcode 16 or later and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
swift test
Scripts/build-local.sh
```

Public builds require Developer ID Application and Developer ID Installer
certificates, Network Extension provisioning, and Apple notarization. See
[Documentation/RELEASING.md](Documentation/RELEASING.md).

## Support

Email `kulibabagood@gmail.com`.

## Disclaimer

HS Reconnect is unofficial and is not affiliated with, endorsed by, or
sponsored by Blizzard Entertainment. Use it at your own risk. Game behavior
and policies may change.

HS Reconnect is free software released under the [MIT License](LICENSE).
