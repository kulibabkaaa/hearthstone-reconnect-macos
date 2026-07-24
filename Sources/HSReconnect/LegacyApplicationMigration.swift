import AppKit

enum LegacyApplicationMigration {
  static let bundleIdentifiers = [
    "com.local.HearthstoneReconnect"
  ]

  @discardableResult
  static func terminateRunningApplications(
    timeout: TimeInterval = 1
  ) -> Bool {
    var legacyApplications: [NSRunningApplication] = []
    for bundleIdentifier in bundleIdentifiers {
      legacyApplications.append(
        contentsOf: NSRunningApplication.runningApplications(
          withBundleIdentifier: bundleIdentifier
        ).filter { $0 != .current }
      )
    }

    for application in legacyApplications {
      guard application.forceTerminate() || application.isTerminated else {
        return false
      }
    }

    let deadline = Date(timeIntervalSinceNow: timeout)
    while legacyApplications.contains(where: { !$0.isTerminated }),
      Date() < deadline
    {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    return legacyApplications.allSatisfy(\.isTerminated)
  }
}
