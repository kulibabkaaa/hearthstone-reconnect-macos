public enum AppUninstallFailureStage: Sendable {
  case extensionStillInstalled
  case extensionDeactivated
}

public enum AppUninstallRecoveryPolicy {
  public static func shouldRestoreRuntime(
    after stage: AppUninstallFailureStage
  ) -> Bool {
    stage == .extensionStillInstalled
  }
}
