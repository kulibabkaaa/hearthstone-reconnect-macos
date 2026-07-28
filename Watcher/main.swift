import AppKit

private enum WatcherConfiguration {
  static let hearthstoneBundleIdentifier =
    "unity.Blizzard Entertainment.Hearthstone"
  static let hostBundleIdentifier =
    "io.github.kulibabkaaa.HSReconnect"
}

final class WatcherDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(
    _ notification: Notification
  ) {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let application = notification.userInfo?[
          NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication,
        application.bundleIdentifier
          == WatcherConfiguration.hearthstoneBundleIdentifier
      else {
        return
      }
      self?.launchHostIfNeeded()
    }

    if !NSRunningApplication.runningApplications(
      withBundleIdentifier:
        WatcherConfiguration.hearthstoneBundleIdentifier
    ).isEmpty {
      launchHostIfNeeded()
    }
  }

  private func launchHostIfNeeded() {
    guard
      NSRunningApplication.runningApplications(
        withBundleIdentifier:
          WatcherConfiguration.hostBundleIdentifier
      ).isEmpty
    else {
      return
    }

    let hostURL = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.arguments = ["--from-hearthstone"]
    NSWorkspace.shared.openApplication(
      at: hostURL,
      configuration: configuration
    )
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = WatcherDelegate()
app.delegate = delegate
app.run()
