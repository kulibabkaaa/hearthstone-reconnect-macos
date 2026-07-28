import AppKit

let app = NSApplication.shared
let delegate = AppDelegate(
  launchedForHearthstone:
    CommandLine.arguments.contains("--from-hearthstone")
)
app.delegate = delegate
app.run()
