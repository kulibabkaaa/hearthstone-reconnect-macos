import Carbon
import Foundation

enum AppConfiguration {
  static let appName = AppIdentity.appName
  static let bundleIdentifier =
    AppIdentity.bundleIdentifier
  static let extensionBundleIdentifier =
    AppIdentity.extensionBundleIdentifier
  static let watcherBundleIdentifier =
    AppIdentity.watcherBundleIdentifier
  static let defaultShortcutKeyCode = UInt32(kVK_ANSI_W)
  static let defaultShortcutDisplay = "Cmd+Shift+W"
  static let openWithHearthstoneByDefault = true
  static let showInDockByDefault = true
}

enum DefaultsKey {
  static let keyCode = "hotkey.keyCode"
  static let modifiers = "hotkey.modifiers"
  static let hotkeyDisplay = "hotkey.display"
  static let openWithHearthstone =
    "openWithHearthstone"
  static let showInDock = "appearance.showInDock"
  static let didConfigureDefaultLoginItem =
    "loginItem.didConfigureDefault"
  static let hasSeenSystemExtensionApprovalPrompt =
    "systemExtension.hasSeenApprovalPrompt"
  static let lastReconnectAt = "reconnect.lastAt"
}

func defaultCarbonModifiers() -> UInt32 {
  UInt32(cmdKey) | UInt32(shiftKey)
}
