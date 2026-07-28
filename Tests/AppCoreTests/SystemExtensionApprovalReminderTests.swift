import Testing

@testable import AppCore

@Suite("System Extension approval reminder")
struct SystemExtensionApprovalReminderTests {
  @Test("relies on the system prompt the first time")
  func firstRequestUsesSystemPrompt() {
    var reminder = SystemExtensionApprovalReminder()

    let shouldPresent = reminder.shouldPresentAppReminder(
      hasSeenSystemPromptBefore: false
    )
    #expect(!shouldPresent)
  }

  @Test("reminds again on a later unapproved launch")
  func laterLaunchShowsReminder() {
    var reminder = SystemExtensionApprovalReminder()

    let shouldPresent = reminder.shouldPresentAppReminder(
      hasSeenSystemPromptBefore: true
    )
    #expect(shouldPresent)
  }

  @Test("shows no duplicate reminder in one launch")
  func oneReminderPerLaunch() {
    var reminder = SystemExtensionApprovalReminder()

    let firstResult = reminder.shouldPresentAppReminder(
      hasSeenSystemPromptBefore: true
    )
    let secondResult = reminder.shouldPresentAppReminder(
      hasSeenSystemPromptBefore: true
    )
    #expect(firstResult)
    #expect(!secondResult)
  }
}
