import Carbon
import Foundation

enum AppConfiguration {
  static let appName = "HS Reconnect"
  static let bundleIdentifier = "io.github.kulibabkaaa.HSReconnect"
  static let watcherBundleIdentifier = "io.github.kulibabkaaa.HSReconnect.Watcher"
  static let version = "1.0.0"

  static let installedHelperPath = "/usr/local/libexec/hsreconnect-helper"
  static let sudoersPath = "/etc/sudoers.d/hsreconnect"

  static let fastResetSeconds: TimeInterval = 3
  static let idleFallbackSeconds: TimeInterval = 10
  static let cooldownSeconds: TimeInterval = 5

  static let defaultShortcutKeyCode: UInt32 = UInt32(kVK_ANSI_W)
  static let defaultShortcutDisplay = "Cmd+Shift+W"
  static let openWithHearthstoneByDefault = true
  static let showInDockByDefault = true
  static let logRetentionDays = 7
}

enum DefaultsKey {
  static let keyCode = "hotkey.keyCode"
  static let modifiers = "hotkey.modifiers"
  static let hotkeyDisplay = "hotkey.display"
  static let openWithHearthstone = "openWithHearthstone"
  static let showInDock = "appearance.showInDock"
  static let didConfigureDefaultLoginItem = "loginItem.didConfigureDefault"
  static let lastReconnectAt = "reconnect.lastAt"
}

func defaultCarbonModifiers() -> UInt32 {
  UInt32(cmdKey) | UInt32(shiftKey)
}
