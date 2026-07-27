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

  func testInstallerAndShortcutRecorderRetireLegacyAppSafely() throws {
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
        "LEGACY_APP=\"$TARGET_ROOT/Applications/Hearthstone Reconnect.app\""
      )
    )
    XCTAssertFalse(postinstall.contains("/usr/bin/pkill"))
    XCTAssertTrue(postinstall.contains("terminate_exact_executable"))
    XCTAssertTrue(postinstall.contains("--unregister-login-item"))
    XCTAssertTrue(postinstall.contains("/usr/bin/shasum -a 256"))
    XCTAssertTrue(postinstall.contains("NOPASSWD: sha256:%s %s"))
    XCTAssertTrue(postinstall.contains("-L \"$SOURCE_HELPER\""))
    XCTAssertTrue(postinstall.contains("ensure_privileged_directory"))
    XCTAssertTrue(postinstall.contains("mode & 0022"))
    XCTAssertFalse(postinstall.contains("/bin/chmod 755 \"$SUDOERS_DIR\""))
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

  func testUninstallerRemovesLegacyFilesWithoutBroadProcessKills() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let uninstaller = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Scripts/uninstall.sh"),
      encoding: .utf8
    )

    XCTAssertFalse(uninstaller.contains("/usr/bin/pkill"))
    XCTAssertTrue(uninstaller.contains("terminate_exact_executable"))
    XCTAssertTrue(
      uninstaller.contains(
        "LEGACY_APP=\"/Applications/Hearthstone Reconnect.app\""
      )
    )
    XCTAssertTrue(uninstaller.contains("LEGACY_BUNDLE_ID="))
    XCTAssertTrue(
      uninstaller.components(
        separatedBy: "--unregister-login-item"
      ).count >= 3
    )
  }

  func testInstallerCreatesAndUninstallerRemovesOnlyItsDesktopShortcut() throws {
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
    let uninstaller = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Scripts/uninstall.sh"),
      encoding: .utf8
    )

    for script in [postinstall, uninstaller] {
      XCTAssertTrue(
        script.contains("DESKTOP_SHORTCUT_NAME=\"HS Reconnect.app\"")
      )
      XCTAssertTrue(script.contains("NFSHomeDirectory"))
      XCTAssertTrue(
        script.contains("/usr/bin/readlink \"$desktop_shortcut\"")
      )
      XCTAssertFalse(script.contains("/bin/rm -rf \"$desktop_shortcut\""))
    }
    XCTAssertTrue(
      postinstall.contains("/bin/ln -s \"$APP\" \"$desktop_shortcut\"")
    )
    XCTAssertTrue(
      uninstaller.contains("/bin/rm -f \"$desktop_shortcut\"")
    )
  }

  func testReleaseVerifierNeverOverwritesDistPackage() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let verifier = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Scripts/verify_release.sh"),
      encoding: .utf8
    )
    let packageBuilder = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Scripts/build_package.sh"),
      encoding: .utf8
    )

    XCTAssertTrue(packageBuilder.contains("PACKAGE_OUTPUT_DIR"))
    XCTAssertTrue(
      verifier.contains(
        "PACKAGE_OUTPUT_DIR=\"$VERIFY_ROOT\""
      )
    )
    XCTAssertTrue(verifier.contains("pkgutil --expand-full"))
    XCTAssertTrue(verifier.contains("PACKAGED_APP"))
    XCTAssertTrue(verifier.contains("\"$ROOT\"/Scripts/*.sh"))
  }

  func testNotarizationCanResumeWithoutPollingApple() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let notarizer = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Scripts/notarize.sh"),
      encoding: .utf8
    )

    XCTAssertFalse(notarizer.contains("--wait"))
    XCTAssertTrue(notarizer.contains("submit)"))
    XCTAssertTrue(notarizer.contains("finish)"))
    XCTAssertTrue(notarizer.contains("notarytool info"))
  }

  func testShortcutRecorderInterceptsMenuShortcutsBeforeDispatch() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let recorder = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent("Sources/HSReconnect/RecorderButton.swift"),
      encoding: .utf8
    )

    XCTAssertTrue(recorder.contains("addLocalMonitorForEvents"))
    XCTAssertTrue(recorder.contains("removeMonitor"))
  }

  func testHelperValidationDoesNotReadProtectedSudoersContents() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let reconnectService = try String(
      contentsOf:
        repositoryRoot
        .appendingPathComponent(
          "Sources/HSReconnect/ReconnectService.swift"
        ),
      encoding: .utf8
    )

    XCTAssertFalse(
      reconnectService.contains(
        "contents(\n        atPath: AppConfiguration.sudoersPath"
      )
    )
    XCTAssertTrue(reconnectService.contains("\"--check\""))
  }
}
