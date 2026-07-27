import AppKit
import Foundation

// Apple defines .regular as Dock-visible and .accessory as Dock-hidden.
// Source: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum
func dockActivationPolicy(
  showInDock: Bool
) -> NSApplication.ActivationPolicy {
  showInDock ? .regular : .accessory
}

final class DockVisibilityController {
  private let defaults: UserDefaults
  private let setActivationPolicy:
    (NSApplication.ActivationPolicy) -> Bool

  init(
    defaults: UserDefaults = .standard,
    setActivationPolicy: @escaping
      (NSApplication.ActivationPolicy) -> Bool = {
        NSApplication.shared.setActivationPolicy($0)
      }
  ) {
    self.defaults = defaults
    self.setActivationPolicy = setActivationPolicy
  }

  @discardableResult
  func applyStoredPreference() -> Bool {
    setActivationPolicy(
      dockActivationPolicy(
        showInDock: defaults.bool(forKey: DefaultsKey.showInDock)
      )
    )
  }

  @discardableResult
  func setEnabled(_ enabled: Bool) -> Bool {
    guard setActivationPolicy(
      dockActivationPolicy(showInDock: enabled)
    ) else {
      return false
    }

    defaults.set(enabled, forKey: DefaultsKey.showInDock)
    return true
  }
}
