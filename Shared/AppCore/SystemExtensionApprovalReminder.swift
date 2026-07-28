public struct SystemExtensionApprovalReminder: Sendable {
  private var didPresentAppReminder = false

  public init() {}

  public mutating func shouldPresentAppReminder(
    hasSeenSystemPromptBefore: Bool
  ) -> Bool {
    guard
      hasSeenSystemPromptBefore,
      !didPresentAppReminder
    else {
      return false
    }
    didPresentAppReminder = true
    return true
  }
}
