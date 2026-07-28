import AppKit

let app = NSApplication.shared
let delegate = AppDelegate(
  launchMode: AppLaunchMode(
    arguments: CommandLine.arguments
  )
)
app.delegate = delegate
app.run()
