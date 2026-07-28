# Architecture

HS Reconnect is a native macOS application with an embedded transparent-proxy
system extension.

## Components

- **HS Reconnect** owns the window, menu bar item, global shortcut, settings,
  system-extension activation, and reconnect command.
- **HS Reconnect Watcher** is an optional login item that opens the host
  quietly when native Hearthstone starts.
- **Proxy Extension** passes matching native Hearthstone flows through to their
  original servers and keeps the active flow references.
- **ProxyCore** contains the shared command, endpoint parsing, flow matching,
  target selection, and cooldown logic.

## Reconnect sequence

1. Hearthstone writes its current game endpoint to its local game log.
2. HS Reconnect reads the latest valid public endpoint.
3. The transparent proxy has already accepted and relayed that Hearthstone
   connection without modifying its contents.
4. The shortcut sends the exact endpoint to the extension.
5. The extension closes that one matching flow.
6. Hearthstone immediately enters its normal reconnect state.

If no valid logged endpoint exists, a TCP 3724 fallback is allowed only when
exactly one native Hearthstone flow matches. Ambiguous flows are never closed.

## Security boundaries

- The Network Extension rule is limited to native Hearthstone's signing
  identifier.
- Reconnect commands require an exact endpoint or an unambiguous fallback.
- No root helper, sudo rule, packet-filter rule, or remote service is used.
- Network contents are relayed unchanged and are not logged.

## Apple platform references

- [Network Extension provider deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- [NETransparentProxyProvider](https://developer.apple.com/documentation/networkextension/netransparentproxyprovider)
- [NEAppProxyFlow](https://developer.apple.com/documentation/networkextension/neappproxyflow)
- [System Extensions](https://developer.apple.com/documentation/systemextensions)
