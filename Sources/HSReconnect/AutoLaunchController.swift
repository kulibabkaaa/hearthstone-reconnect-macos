import Foundation
import ServiceManagement

enum AutoLaunchError: Error {
  case approvalRequired
  case unavailable
}

final class AutoLaunchController {
  private var service: SMAppService {
    SMAppService.loginItem(
      identifier: AppConfiguration.watcherBundleIdentifier
    )
  }

  func configureDefaultIfNeeded() -> Result<Void, Error> {
    let defaults = UserDefaults.standard
    guard
      !defaults.bool(
        forKey: DefaultsKey.didConfigureDefaultLoginItem
      )
    else {
      return .success(())
    }

    defaults.set(
      AppConfiguration.openWithHearthstoneByDefault,
      forKey: DefaultsKey.openWithHearthstone
    )
    let result = setEnabled(
      AppConfiguration.openWithHearthstoneByDefault
    )
    if case .success = result {
      defaults.set(
        true,
        forKey: DefaultsKey.didConfigureDefaultLoginItem
      )
    }
    return result
  }

  func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
    do {
      if enabled {
        if service.status == .notRegistered || service.status == .notFound {
          try service.register()
        }
        UserDefaults.standard.set(
          true,
          forKey: DefaultsKey.openWithHearthstone
        )
        if service.status == .requiresApproval {
          return .failure(AutoLaunchError.approvalRequired)
        }
        guard service.status == .enabled else {
          return .failure(AutoLaunchError.unavailable)
        }
      } else {
        if service.status != .notRegistered && service.status != .notFound {
          try service.unregister()
        }
        UserDefaults.standard.set(
          false,
          forKey: DefaultsKey.openWithHearthstone
        )
      }
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  func unregisterForUninstall() -> Bool {
    do {
      if service.status != .notRegistered && service.status != .notFound {
        try service.unregister()
      }
      return true
    } catch {
      return false
    }
  }
}
