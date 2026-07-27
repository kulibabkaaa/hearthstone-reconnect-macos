import AppKit
import ServiceManagement

if CommandLine.arguments.contains("--unregister-login-item") {
  let success = AutoLaunchController().unregisterForUninstall()
  exit(success ? 0 : 1)
}

if let optionIndex = CommandLine.arguments.firstIndex(
  of: "--create-desktop-shortcut"
) {
  let shortcutIndex = CommandLine.arguments.index(after: optionIndex)
  guard CommandLine.arguments.indices.contains(shortcutIndex) else {
    exit(64)
  }

  do {
    try DesktopShortcutInstaller.createAliasIfNeeded(
      applicationURL: Bundle.main.bundleURL,
      shortcutURL: URL(
        fileURLWithPath: CommandLine.arguments[shortcutIndex]
      )
    )
    exit(0)
  } catch {
    exit(1)
  }
}

let launchedForHearthstone = CommandLine.arguments.contains(
  "--from-hearthstone"
)
let app = NSApplication.shared
let delegate = AppDelegate(
  launchedForHearthstone: launchedForHearthstone
)
app.delegate = delegate
app.run()
