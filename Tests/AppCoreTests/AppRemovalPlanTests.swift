import AppKit
import Foundation
import Testing

@testable import AppCore

@Suite("App removal plan")
struct AppRemovalPlanTests {
  private let home = URL(fileURLWithPath: "/Users/Test Person")

  @Test("removes only the installed app and exact package receipt")
  func installedArtifactsAreExact() {
    let plan = AppRemovalPlan(homeDirectory: home)

    #expect(
      plan.installedApplicationURL.path
        == "/Applications/HS Reconnect.app"
    )
    #expect(
      plan.packageReceiptIdentifier
        == "io.github.kulibabkaaa.HSReconnect.installer"
    )
  }

  @Test("owns only this app's transparent proxy")
  func proxyOwnershipIsExact() {
    #expect(
      AppRemovalPlan.ownsProxyConfiguration(
        providerBundleIdentifier:
          "io.github.kulibabkaaa.HSReconnect.ProxyExtension"
      )
    )
    #expect(
      !AppRemovalPlan.ownsProxyConfiguration(
        providerBundleIdentifier:
          "io.github.kulibabkaaa.HSReconnect.OtherExtension"
      )
    )
    #expect(
      !AppRemovalPlan.ownsProxyConfiguration(
        providerBundleIdentifier: nil
      )
    )
  }

  @Test("removes only the Desktop symlink targeting the installed app")
  func desktopShortcutOwnershipIsExact() {
    let plan = AppRemovalPlan(homeDirectory: home)

    #expect(
      plan.desktopShortcutURL.path
        == "/Users/Test Person/Desktop/HS Reconnect.app"
    )
    #expect(
      plan.ownsDesktopShortcut(
        destination:
          URL(fileURLWithPath: "/Applications/HS Reconnect.app")
      )
    )
    #expect(
      !plan.ownsDesktopShortcut(
        destination:
          URL(fileURLWithPath: "/Applications/Another App.app")
      )
    )
  }

  @Test("user data paths stay inside the current user's Library")
  func userDataIsScoped() {
    let plan = AppRemovalPlan(homeDirectory: home)
    let libraryPrefix = "/Users/Test Person/Library/"

    #expect(!plan.userDataURLs.isEmpty)
    #expect(
      plan.userDataURLs.allSatisfy {
        $0.path.hasPrefix(libraryPrefix)
      }
    )
    #expect(
      plan.userDataURLs.contains {
        $0.path
          == "/Users/Test Person/Library/Group Containers/D8KUYWS8JN.io.github.kulibabkaaa.HSReconnect"
      }
    )
    #expect(
      plan.userDataURLs.contains {
        $0.path
          == "/Users/Test Person/Library/Containers/io.github.kulibabkaaa.HSReconnect.ProxyExtension"
      }
    )
  }

  @Test("privileged removal command quotes paths")
  func privilegedCommandIsSafelyQuoted() {
    let plan = AppRemovalPlan(homeDirectory: home)
    let command = plan.privilegedRemovalCommand

    #expect(
      command.contains(
        "'/Applications/HS Reconnect.app'"
      )
    )
    #expect(
      command.contains(
        "'/Users/Test Person/Library/Group Containers/D8KUYWS8JN.io.github.kulibabkaaa.HSReconnect'"
      )
    )
    #expect(
      command.contains(
        "'io.github.kulibabkaaa.HSReconnect.installer'"
      )
    )
  }

  @Test("AppleScript wraps the fixed command without interpolation")
  func privilegedAppleScriptIsEscaped() {
    let plan = AppRemovalPlan(homeDirectory: home)

    #expect(
      plan.privilegedRemovalAppleScript.hasPrefix(
        "do shell script \"set -e;"
      )
    )
    #expect(
      plan.privilegedRemovalAppleScript.hasSuffix(
        "\" with administrator privileges"
      )
    )
  }

  @Test("privileged removal AppleScript compiles")
  func privilegedAppleScriptCompiles() {
    let plan = AppRemovalPlan(homeDirectory: home)
    let script = NSAppleScript(
      source: plan.privilegedRemovalAppleScript
    )
    var error: NSDictionary?

    #expect(script?.compileAndReturnError(&error) == true)
    #expect(error == nil)
  }
}
