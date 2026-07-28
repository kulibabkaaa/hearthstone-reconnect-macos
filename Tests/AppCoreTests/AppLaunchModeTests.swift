import Testing

@testable import AppCore

@Suite("App launch mode")
struct AppLaunchModeTests {
  @Test("normal launch does not use the Hearthstone watcher mode")
  func normalLaunch() {
    #expect(
      AppLaunchMode(arguments: ["/Applications/HS Reconnect.app"])
        == .normal(launchedForHearthstone: false)
    )
  }

  @Test("Hearthstone watcher launch stays in the background")
  func hearthstoneLaunch() {
    #expect(
      AppLaunchMode(
        arguments: [
          "/Applications/HS Reconnect.app",
          "--from-hearthstone",
        ]
      ) == .normal(launchedForHearthstone: true)
    )
  }

  @Test("uninstall relaunch waits for the original process")
  func uninstallRelaunch() {
    #expect(
      AppLaunchMode(
        arguments: [
          "/Applications/HS Reconnect.app",
          "--resume-uninstall-after-pid",
          "1234",
          "--from-hearthstone",
        ]
      ) == .resumeUninstall(waitingForProcessIdentifier: 1234)
    )
  }

  @Test("invalid uninstall process identifiers are ignored")
  func invalidUninstallProcessIdentifier() {
    #expect(
      AppLaunchMode(
        arguments: [
          "/Applications/HS Reconnect.app",
          "--resume-uninstall-after-pid",
          "-1",
        ]
      ) == .normal(launchedForHearthstone: false)
    )
  }
}
