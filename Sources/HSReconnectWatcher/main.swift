import AppKit

private enum WatcherConfiguration {
  static let hearthstoneBundleIdentifier =
    "unity.Blizzard Entertainment.Hearthstone"
  static let mainAppBundleIdentifier =
    "io.github.kulibabkaaa.HSReconnect"
}

final class WatcherDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self,
        let application = notification.userInfo?[
          NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication,
        application.bundleIdentifier == WatcherConfiguration.hearthstoneBundleIdentifier
      else {
        return
      }
      self.launchMainAppIfNeeded()
    }

    if !NSRunningApplication.runningApplications(
      withBundleIdentifier:
        WatcherConfiguration.hearthstoneBundleIdentifier
    ).isEmpty {
      launchMainAppIfNeeded()
    }
  }

  private func launchMainAppIfNeeded() {
    guard
      NSRunningApplication.runningApplications(
        withBundleIdentifier:
          WatcherConfiguration.mainAppBundleIdentifier
      ).isEmpty
    else {
      return
    }

    let mainAppURL = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.arguments = ["--from-hearthstone"]
    NSWorkspace.shared.openApplication(
      at: mainAppURL,
      configuration: configuration
    )
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = WatcherDelegate()
app.delegate = delegate
app.run()
