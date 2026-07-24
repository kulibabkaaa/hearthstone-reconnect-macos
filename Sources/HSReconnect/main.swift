import AppKit
import ServiceManagement

if CommandLine.arguments.contains("--unregister-login-item") {
  let success = AutoLaunchController().unregisterForUninstall()
  exit(success ? 0 : 1)
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
