import Testing

@testable import AppCore

@Suite("App uninstall recovery")
struct AppUninstallRecoveryTests {
  @Test("does not restart services after the extension was removed")
  func doesNotReactivateAfterExtensionRemoval() {
    #expect(
      !AppUninstallRecoveryPolicy.shouldRestoreRuntime(
        after: .extensionDeactivated
      )
    )
  }

  @Test("can restore services before the extension was removed")
  func restoresBeforeExtensionRemoval() {
    #expect(
      AppUninstallRecoveryPolicy.shouldRestoreRuntime(
        after: .extensionStillInstalled
      )
    )
  }
}
