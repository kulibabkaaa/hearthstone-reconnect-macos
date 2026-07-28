import Foundation

public enum AppIdentity {
  public static let appName = "HS Reconnect"
  public static let bundleIdentifier =
    "io.github.kulibabkaaa.HSReconnect"
  public static let extensionBundleIdentifier =
    "io.github.kulibabkaaa.HSReconnect.ProxyExtension"
  public static let watcherBundleIdentifier =
    "io.github.kulibabkaaa.HSReconnect.Watcher"
  public static let packageReceiptIdentifier =
    "io.github.kulibabkaaa.HSReconnect.installer"
  public static let applicationGroupIdentifier =
    "D8KUYWS8JN.io.github.kulibabkaaa.HSReconnect"
}

public struct AppRemovalPlan: Sendable {
  public let installedApplicationURL: URL
  public let packageReceiptIdentifier: String
  public let desktopShortcutURL: URL
  public let userDataURLs: [URL]

  public init(homeDirectory: URL) {
    installedApplicationURL = URL(
      fileURLWithPath: "/Applications/HS Reconnect.app"
    )
    packageReceiptIdentifier =
      AppIdentity.packageReceiptIdentifier
    desktopShortcutURL =
      homeDirectory
      .appendingPathComponent("Desktop", isDirectory: true)
      .appendingPathComponent(
        "HS Reconnect.app",
        isDirectory: false
      )

    let library = homeDirectory.appendingPathComponent(
      "Library",
      isDirectory: true
    )
    userDataURLs = [
      library
        .appendingPathComponent("Preferences", isDirectory: true)
        .appendingPathComponent(
          "\(AppIdentity.bundleIdentifier).plist"
        ),
      library
        .appendingPathComponent("Preferences", isDirectory: true)
        .appendingPathComponent(
          "\(AppIdentity.watcherBundleIdentifier).plist"
        ),
      library
        .appendingPathComponent("Caches", isDirectory: true)
        .appendingPathComponent(
          AppIdentity.bundleIdentifier,
          isDirectory: true
        ),
      library
        .appendingPathComponent(
          "Application Support",
          isDirectory: true
        )
        .appendingPathComponent(
          AppIdentity.appName,
          isDirectory: true
        ),
      library
        .appendingPathComponent(
          "Containers",
          isDirectory: true
        )
        .appendingPathComponent(
          AppIdentity.bundleIdentifier,
          isDirectory: true
        ),
      library
        .appendingPathComponent(
          "Containers",
          isDirectory: true
        )
        .appendingPathComponent(
          AppIdentity.extensionBundleIdentifier,
          isDirectory: true
        ),
      library
        .appendingPathComponent(
          "Group Containers",
          isDirectory: true
        )
        .appendingPathComponent(
          AppIdentity.applicationGroupIdentifier,
          isDirectory: true
        ),
    ]
  }

  public static func ownsProxyConfiguration(
    providerBundleIdentifier: String?
  ) -> Bool {
    providerBundleIdentifier
      == AppIdentity.extensionBundleIdentifier
  }

  public func ownsDesktopShortcut(
    destination: URL
  ) -> Bool {
    destination.standardizedFileURL
      == installedApplicationURL.standardizedFileURL
  }

  public var privilegedRemovalCommand: String {
    let desktopShortcut = Self.shellQuote(
      desktopShortcutURL.path
    )
    let installedApplication = Self.shellQuote(
      installedApplicationURL.path
    )
    let desktopShortcutCommand =
      "if [ -L \(desktopShortcut) ]"
      + " && [ \"$(/usr/bin/readlink \(desktopShortcut))\""
      + " = \(installedApplication) ];"
      + " then /bin/rm -f -- \(desktopShortcut); fi"
    let userDataCommands = userDataURLs.map {
      "/bin/rm -rf -- \(Self.shellQuote($0.path))"
        + " >/dev/null 2>&1 || true"
    }
    return
      (["set -e", desktopShortcutCommand]
      + userDataCommands + [
        "/bin/rm -rf -- "
          + installedApplication,
        "/usr/sbin/pkgutil --forget "
          + Self.shellQuote(packageReceiptIdentifier)
          + " >/dev/null 2>&1 || true",
      ]).joined(separator: "; ")
  }

  public var privilegedRemovalAppleScript: String {
    "do shell script \(Self.appleScriptQuote(privilegedRemovalCommand)) with administrator privileges"
  }

  private static func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private static func appleScriptQuote(_ value: String) -> String {
    let escaped =
      value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
    return "\"\(escaped)\""
  }
}
