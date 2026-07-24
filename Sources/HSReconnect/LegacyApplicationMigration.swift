import AppKit

enum LegacyApplicationMigration {
  static let bundleIdentifiers = [
    "com.local.HearthstoneReconnect"
  ]

  static func terminateRunningApplications() {
    var legacyApplications: [NSRunningApplication] = []
    for bundleIdentifier in bundleIdentifiers {
      legacyApplications.append(
        contentsOf: NSRunningApplication.runningApplications(
          withBundleIdentifier: bundleIdentifier
        ).filter { $0 != .current }
      )
    }

    for application in legacyApplications {
      _ = application.forceTerminate()
    }

    let deadline = Date(timeIntervalSinceNow: 0.5)
    while legacyApplications.contains(where: { !$0.isTerminated }),
      Date() < deadline
    {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }
  }
}
