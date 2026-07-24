import AppKit
import ServiceManagement

enum AutoLaunchError: Error {
  case approvalRequired
  case unavailable
  case watcherCouldNotStop
}

protocol LoginItemService: AnyObject {
  var status: SMAppService.Status { get }
  func register() throws
  func unregister() throws
}

extension SMAppService: LoginItemService {}

final class AutoLaunchController {
  private let service: any LoginItemService
  private let defaults: UserDefaults
  private let stopWatcher: () -> Bool

  convenience init() {
    self.init(
      service: SMAppService.loginItem(
        identifier: AppConfiguration.watcherBundleIdentifier
      ),
      defaults: .standard,
      stopWatcher: AutoLaunchController.stopRunningWatcher
    )
  }

  init(
    service: any LoginItemService,
    defaults: UserDefaults,
    stopWatcher: @escaping () -> Bool
  ) {
    self.service = service
    self.defaults = defaults
    self.stopWatcher = stopWatcher
  }

  func synchronizeStoredState() {
    defaults.set(
      service.status == .enabled,
      forKey: DefaultsKey.openWithHearthstone
    )
  }

  func configureDefaultIfNeeded() -> Result<Void, Error> {
    guard
      !defaults.bool(
        forKey: DefaultsKey.didConfigureDefaultLoginItem
      )
    else {
      return .success(())
    }

    defer {
      defaults.set(
        true,
        forKey: DefaultsKey.didConfigureDefaultLoginItem
      )
    }
    let result = setEnabled(
      AppConfiguration.openWithHearthstoneByDefault
    )
    return result
  }

  func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
    do {
      if enabled {
        if service.status == .notRegistered || service.status == .notFound {
          try service.register()
        }
        if service.status == .requiresApproval {
          defaults.set(
            false,
            forKey: DefaultsKey.openWithHearthstone
          )
          return .failure(AutoLaunchError.approvalRequired)
        }
        guard service.status == .enabled else {
          try? service.unregister()
          defaults.set(
            false,
            forKey: DefaultsKey.openWithHearthstone
          )
          return .failure(AutoLaunchError.unavailable)
        }
        defaults.set(
          true,
          forKey: DefaultsKey.openWithHearthstone
        )
      } else {
        if service.status != .notRegistered && service.status != .notFound {
          try service.unregister()
        }
        defaults.set(
          false,
          forKey: DefaultsKey.openWithHearthstone
        )
        guard stopWatcher() else {
          return .failure(AutoLaunchError.watcherCouldNotStop)
        }
      }
      return .success(())
    } catch {
      if enabled {
        defaults.set(
          false,
          forKey: DefaultsKey.openWithHearthstone
        )
      }
      return .failure(error)
    }
  }

  func unregisterForUninstall() -> Bool {
    var success = true
    do {
      if service.status != .notRegistered && service.status != .notFound {
        try service.unregister()
      }
    } catch {
      success = false
    }
    return stopWatcher() && success
  }

  private static func stopRunningWatcher() -> Bool {
    let applications = NSRunningApplication.runningApplications(
      withBundleIdentifier: AppConfiguration.watcherBundleIdentifier
    ).filter { !$0.isTerminated }

    for application in applications {
      if !application.terminate() {
        _ = application.forceTerminate()
      }
    }
    waitForTermination(of: applications)

    for application in applications where !application.isTerminated {
      _ = application.forceTerminate()
    }
    waitForTermination(of: applications)
    return applications.allSatisfy(\.isTerminated)
  }

  private static func waitForTermination(
    of applications: [NSRunningApplication]
  ) {
    let deadline = Date(timeIntervalSinceNow: 1)
    while applications.contains(where: { !$0.isTerminated }),
      Date() < deadline
    {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }
  }
}
