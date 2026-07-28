import AppKit

final class DockVisibilityChangeCoordinator {
  private var latestRequestID: UInt64 = 0

  func submit(
    _ enabled: Bool,
    apply: @escaping (Bool) -> Void
  ) {
    latestRequestID &+= 1
    let requestID = latestRequestID
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      [weak self] in
      guard self?.latestRequestID == requestID else { return }
      apply(enabled)
    }
  }
}

final class DockVisibilityController {
  private let defaults = UserDefaults.standard

  @discardableResult
  func applyStoredPreference() -> Bool {
    apply(defaults.bool(forKey: DefaultsKey.showInDock))
  }

  @discardableResult
  func setEnabled(_ enabled: Bool) -> Bool {
    guard apply(enabled) else { return false }
    defaults.set(enabled, forKey: DefaultsKey.showInDock)
    return true
  }

  private func apply(_ enabled: Bool) -> Bool {
    let policy: NSApplication.ActivationPolicy =
      enabled ? .regular : .accessory
    if NSApp.activationPolicy() == policy {
      return true
    }
    return NSApp.setActivationPolicy(policy)
      || NSApp.activationPolicy() == policy
  }
}
