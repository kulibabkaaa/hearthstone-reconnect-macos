import XCTest

@testable import HSReconnect

final class ProductBehaviorTests: XCTestCase {
  func testPublicReleaseUsesFixedReconnectTiming() {
    XCTAssertEqual(AppConfiguration.fastResetSeconds, 3)
    XCTAssertEqual(AppConfiguration.idleFallbackSeconds, 10)
    XCTAssertEqual(AppConfiguration.cooldownSeconds, 5)
  }

  func testCooldownUsesTheHelpersNetworkTouchTimestamp() {
    XCTAssertEqual(
      helperNetworkTouchTimestamp(
        "status\nHSRECONNECT_NETWORK_TOUCHED_AT=1784900000\ncomplete"
      ),
      1_784_900_000
    )
    XCTAssertNil(
      helperNetworkTouchTimestamp("Reconnect did not touch the network.")
    )
  }

  func testDefaultShortcutIsCommandShiftW() {
    XCTAssertEqual(AppConfiguration.defaultShortcutKeyCode, 13)
    XCTAssertEqual(AppConfiguration.defaultShortcutDisplay, "Cmd+Shift+W")
  }

  func testOpenWithHearthstoneIsEnabledByDefault() {
    XCTAssertTrue(AppConfiguration.openWithHearthstoneByDefault)
  }

  func testLegacyReconnectAppIsRetired() {
    XCTAssertEqual(
      LegacyApplicationMigration.bundleIdentifiers,
      ["com.local.HearthstoneReconnect"]
    )
  }

  func testFriendlyMessageForMissingHearthstone() {
    let message = friendlyReconnectFailure(
      for: "Native Hearthstone is not running."
    )
    XCTAssertEqual(message, "Open Hearthstone and try again.")
  }

  func testFriendlyMessageForMissingBattlegroundsGame() {
    let message = friendlyReconnectFailure(
      for: "No active native Hearthstone Battlegrounds TCP/3724 connection was found."
    )
    XCTAssertEqual(message, "Start a Battlegrounds game and try again.")
  }

  func testFriendlyMessageForHelperProblem() {
    let message = friendlyReconnectFailure(
      for: "sudo: a password is required"
    )
    XCTAssertEqual(
      message,
      "HS Reconnect needs to be reinstalled. Download and run the latest installer."
    )
  }

  func testFriendlyMessageDoesNotExposeUnknownTechnicalDetails() {
    let message = friendlyReconnectFailure(
      for: "pfctl returned status 17 for anchor com.apple/000.hsreconnect"
    )
    XCTAssertEqual(message, "Reconnect couldn't be completed. Please try again.")
  }

  func testLogRedactionRemovesIPv4AndIPv6Addresses() {
    let value = "local=192.168.4.138:51234 remote=5.42.176.180:1119 ipv6=2001:db8::1"
    let redacted = redactSensitiveNetworkDetails(value)

    XCTAssertFalse(redacted.contains("192.168.4.138"))
    XCTAssertFalse(redacted.contains("5.42.176.180"))
    XCTAssertFalse(redacted.contains("2001:db8::1"))
    XCTAssertTrue(redacted.contains("[address]"))
  }

  func testSevenDayOldLogsAreRemoved() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)
    let sixDaysAgo = now.addingTimeInterval(-6 * 24 * 60 * 60)

    XCTAssertTrue(shouldRemoveLog(modifiedAt: eightDaysAgo, now: now))
    XCTAssertFalse(shouldRemoveLog(modifiedAt: sixDaysAgo, now: now))
  }

  func testAutomaticLaunchQuitsWithHearthstoneUnlessUserOpensWindow() {
    XCTAssertTrue(
      shouldQuitWhenHearthstoneCloses(
        launchedForHearthstone: true,
        userOpenedWindow: false
      )
    )
    XCTAssertFalse(
      shouldQuitWhenHearthstoneCloses(
        launchedForHearthstone: true,
        userOpenedWindow: true
      )
    )
    XCTAssertFalse(
      shouldQuitWhenHearthstoneCloses(
        launchedForHearthstone: false,
        userOpenedWindow: false
      )
    )
  }
}
