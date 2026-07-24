import XCTest
import AppKit
import Carbon
import ServiceManagement

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

  func testShortcutDisplayUsesCommandFirst() {
    XCTAssertEqual(
      displayModifiers(from: [.command, .shift]),
      "Cmd+Shift"
    )
    XCTAssertEqual(
      displayModifiers(from: [.command, .option, .control]),
      "Cmd+Option+Ctrl"
    )
  }

  func testAccessibilityPressStartsShortcutRecording() {
    let button = RecorderButton(title: "Cmd+Shift+W", target: nil, action: nil)

    XCTAssertTrue(button.accessibilityPerformPress())
    XCTAssertEqual(button.title, "Press shortcut…")
  }

  func testShortcutRecordingCancelsWhenFocusMovesAway() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    let button = RecorderButton(title: "Cmd+Shift+W", target: nil, action: nil)
    window.contentView?.addSubview(button)
    var message = ""
    button.onValidationMessage = { message = $0 }

    button.beginRecording()
    window.makeFirstResponder(nil)

    XCTAssertEqual(button.title, "Cmd+Shift+W")
    XCTAssertEqual(message, "Shortcut change cancelled.")
  }

  func testCommandQCannotBecomeTheGlobalShortcut() {
    XCTAssertEqual(
      shortcutValidationMessage(
        keyCode: UInt32(kVK_ANSI_Q),
        modifiers: UInt32(cmdKey)
      ),
      "Choose a shortcut other than Command-Q."
    )
  }

  func testCommandOneCanBecomeTheGlobalShortcut() {
    XCTAssertNil(
      shortcutValidationMessage(
        keyCode: UInt32(kVK_ANSI_1),
        modifiers: UInt32(cmdKey)
      )
    )
  }

  func testInvalidStoredShortcutFallsBackWithoutTrapping() {
    let defaults = UserDefaults(
      suiteName: "ProductBehaviorTests.invalidShortcut"
    )!
    defer {
      defaults.removePersistentDomain(
        forName: "ProductBehaviorTests.invalidShortcut"
      )
    }
    defaults.set(-1, forKey: DefaultsKey.keyCode)
    defaults.set(Int.max, forKey: DefaultsKey.modifiers)

    let shortcut = storedShortcut(in: defaults)

    XCTAssertEqual(shortcut.keyCode, AppConfiguration.defaultShortcutKeyCode)
    XCTAssertEqual(shortcut.modifiers, defaultCarbonModifiers())
    XCTAssertEqual(shortcut.display, AppConfiguration.defaultShortcutDisplay)
  }

  func testFarFutureCooldownTimestampDoesNotDisableReconnectForever() {
    XCTAssertEqual(
      cooldownRemaining(
        lastReconnectAt: 2_000,
        now: 1_000
      ),
      0
    )
  }

  func testOpenWithHearthstoneIsEnabledByDefault() {
    XCTAssertTrue(AppConfiguration.openWithHearthstoneByDefault)
  }

  func testAutoLaunchPreferenceStaysOffWhenApprovalIsRequired() {
    let suiteName = "ProductBehaviorTests.autoLaunchApproval"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let service = FakeLoginItemService(
      status: .notRegistered,
      statusAfterRegister: .requiresApproval
    )
    let controller = AutoLaunchController(
      service: service,
      defaults: defaults,
      stopWatcher: { true }
    )

    XCTAssertThrowsError(try controller.setEnabled(true).get())
    XCTAssertFalse(defaults.bool(forKey: DefaultsKey.openWithHearthstone))
    XCTAssertEqual(service.unregisterCount, 0)
  }

  func testFailedDefaultAutoLaunchIsNotRetriedAtEveryLaunch() {
    let suiteName = "ProductBehaviorTests.autoLaunchRetry"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let service = FakeLoginItemService(
      status: .notRegistered,
      statusAfterRegister: .requiresApproval
    )
    let controller = AutoLaunchController(
      service: service,
      defaults: defaults,
      stopWatcher: { true }
    )

    XCTAssertThrowsError(
      try controller.configureDefaultIfNeeded().get()
    )
    XCTAssertNoThrow(
      try controller.configureDefaultIfNeeded().get()
    )
    XCTAssertEqual(service.registerCount, 1)
  }

  func testAutoLaunchPreferenceTracksTheActualServiceStatus() {
    let suiteName = "ProductBehaviorTests.autoLaunchStatus"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(true, forKey: DefaultsKey.openWithHearthstone)
    let service = FakeLoginItemService(
      status: .requiresApproval,
      statusAfterRegister: .requiresApproval
    )
    let controller = AutoLaunchController(
      service: service,
      defaults: defaults,
      stopWatcher: { true }
    )

    controller.synchronizeStoredState()

    XCTAssertFalse(defaults.bool(forKey: DefaultsKey.openWithHearthstone))
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

  func testDiagnosticLogFilesArePrivateToTheCurrentUser() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let logFile = root.appendingPathComponent("test.log")

    try AppLog.ensurePrivateDirectory(at: root)
    try AppLog.ensurePrivateLogFile(at: logFile)

    let directoryMode = try XCTUnwrap(
      FileManager.default.attributesOfItem(atPath: root.path)[
        .posixPermissions
      ] as? NSNumber
    ).intValue
    let fileMode = try XCTUnwrap(
      FileManager.default.attributesOfItem(atPath: logFile.path)[
        .posixPermissions
      ] as? NSNumber
    ).intValue
    XCTAssertEqual(directoryMode & 0o777, 0o700)
    XCTAssertEqual(fileMode & 0o777, 0o600)
  }

  func testDiagnosticLogMessagesAreBounded() {
    let message = String(repeating: "x", count: 20_000)
    XCTAssertEqual(boundedLogMessage(message).count, 16_000)
  }

  func testPrivilegedFilesRejectLoosePermissionsAndSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    let file = root.appendingPathComponent("helper")
    XCTAssertTrue(
      FileManager.default.createFile(
        atPath: file.path,
        contents: Data("#!/bin/bash\n".utf8),
        attributes: [.posixPermissions: 0o700]
      )
    )
    let attributes = try FileManager.default.attributesOfItem(
      atPath: file.path
    )
    let ownerID = try XCTUnwrap(
      attributes[.ownerAccountID] as? NSNumber
    ).intValue
    let groupID = try XCTUnwrap(
      attributes[.groupOwnerAccountID] as? NSNumber
    ).intValue

    XCTAssertNil(
      privilegedFileIssue(
        atPath: file.path,
        expectedPermissions: 0o700,
        ownerID: ownerID,
        groupID: groupID
      )
    )

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o777],
      ofItemAtPath: file.path
    )
    XCTAssertNotNil(
      privilegedFileIssue(
        atPath: file.path,
        expectedPermissions: 0o700,
        ownerID: ownerID,
        groupID: groupID
      )
    )

    let symlink = root.appendingPathComponent("helper-link")
    try FileManager.default.createSymbolicLink(
      at: symlink,
      withDestinationURL: file
    )
    XCTAssertNotNil(
      privilegedFileIssue(
        atPath: symlink.path,
        expectedPermissions: 0o777,
        ownerID: ownerID,
        groupID: groupID
      )
    )
  }

  func testSudoersAuthorizationBindsTheExactHelperDigest() {
    XCTAssertEqual(
      expectedSudoersEntry(
        user: "test-user",
        helperData: Data("abc".utf8)
      ),
      "test-user ALL=(root) NOPASSWD: "
        + "sha256:ba7816bf8f01cfea414140de5dae2223"
        + "b00361a396177a9cb410ff61f20015ad "
        + "/usr/local/libexec/hsreconnect-helper"
    )
  }

  func testProcessOutputCaptureDoesNotDeadlockOnLargeOutput() throws {
    let result = try runProcessCapturingCombinedOutput(
      executableURL: URL(fileURLWithPath: "/usr/bin/awk"),
      arguments: [
        "BEGIN { for (i = 0; i < 20000; i++) print \"helper output\" }"
      ]
    )

    XCTAssertEqual(result.status, 0)
    XCTAssertGreaterThan(result.output.utf8.count, 200_000)
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

private final class FakeLoginItemService: LoginItemService {
  var status: SMAppService.Status
  let statusAfterRegister: SMAppService.Status
  private(set) var registerCount = 0
  private(set) var unregisterCount = 0

  init(
    status: SMAppService.Status,
    statusAfterRegister: SMAppService.Status
  ) {
    self.status = status
    self.statusAfterRegister = statusAfterRegister
  }

  func register() throws {
    registerCount += 1
    status = statusAfterRegister
  }

  func unregister() throws {
    unregisterCount += 1
    status = .notRegistered
  }
}
