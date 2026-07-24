import Foundation
import XCTest

final class PackagingContractTests: XCTestCase {
  func testInstallerDisablesBundleRelocation() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let componentPlistURL =
      repositoryRoot
      .appendingPathComponent("Packaging")
      .appendingPathComponent("HSReconnect-component.plist")
    let plistData = try Data(contentsOf: componentPlistURL)
    let components = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: plistData, format: nil)
        as? [[String: Any]]
    )
    let appComponent = try XCTUnwrap(components.first)

    XCTAssertEqual(appComponent["BundleIsRelocatable"] as? Bool, false)
    XCTAssertEqual(
      appComponent["RootRelativeBundlePath"] as? String,
      "HS Reconnect.app"
    )

    let buildScriptURL =
      repositoryRoot
      .appendingPathComponent("Scripts")
      .appendingPathComponent("build_package.sh")
    let buildScript = try String(contentsOf: buildScriptURL, encoding: .utf8)
    XCTAssertTrue(
      buildScript.contains(
        "--component-plist \"$ROOT/Packaging/HSReconnect-component.plist\""
      )
    )
  }

  func testReleaseVerifierBuildsAppOutsideWorkspace() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let verifierURL =
      repositoryRoot
      .appendingPathComponent("Scripts")
      .appendingPathComponent("verify_release.sh")
    let verifier = try String(contentsOf: verifierURL, encoding: .utf8)

    XCTAssertTrue(
      verifier.contains(
        "VERIFY_ROOT=\"$(/usr/bin/mktemp -d"
      )
    )
    XCTAssertTrue(
      verifier.contains(
        "APP_OUTPUT_DIR=\"$VERIFY_ROOT\" \"$ROOT/Scripts/build_app.sh\""
      )
    )
    XCTAssertFalse(verifier.contains("grep -qv \"get-task-allow\""))
    XCTAssertTrue(verifier.contains("grep -q \"get-task-allow\""))
  }

  func testInstallerAndShortcutRecorderRetireLegacyApp() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let postinstall = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Packaging/scripts/postinstall"),
      encoding: .utf8
    )
    let appDelegate = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Sources/HSReconnect/AppDelegate.swift"),
      encoding: .utf8
    )
    let recorderButton = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Sources/HSReconnect/RecorderButton.swift"),
      encoding: .utf8
    )

    XCTAssertTrue(
      postinstall.contains(
        "LEGACY_APP=\"$TARGET_VOLUME/Applications/Hearthstone Reconnect.app\""
      )
    )
    XCTAssertTrue(
      postinstall.contains("/usr/bin/pkill -x HearthstoneReconnect")
    )
    XCTAssertTrue(postinstall.contains("/bin/rm -rf \"$LEGACY_APP\""))
    XCTAssertTrue(
      postinstall.contains("defaults delete \"$LEGACY_BUNDLE_ID\"")
    )
    XCTAssertTrue(
      appDelegate.contains(
        "LegacyApplicationMigration.terminateRunningApplications()"
      )
    )
    XCTAssertTrue(
      recorderButton.contains(
        "LegacyApplicationMigration.terminateRunningApplications()"
      )
    )
  }
}
