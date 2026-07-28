import AppKit

enum AppUninstallerError: Error {
  case notInstalledInApplications
  case removalFailedAfterExtensionDeactivation

  var failureStage: AppUninstallFailureStage {
    switch self {
    case .notInstalledInApplications:
      .extensionStillInstalled
    case .removalFailedAfterExtensionDeactivation:
      .extensionDeactivated
    }
  }
}

final class AppUninstaller {
  private let autoLaunchController: AutoLaunchController
  private let proxyController: TransparentProxyController
  private let systemExtensionController: SystemExtensionController
  private let fileManager: FileManager
  private let plan: AppRemovalPlan

  init(
    autoLaunchController: AutoLaunchController,
    proxyController: TransparentProxyController,
    systemExtensionController: SystemExtensionController,
    fileManager: FileManager = .default,
    homeDirectory: URL = FileManager.default
      .homeDirectoryForCurrentUser
  ) {
    self.autoLaunchController = autoLaunchController
    self.proxyController = proxyController
    self.systemExtensionController = systemExtensionController
    self.fileManager = fileManager
    plan = AppRemovalPlan(homeDirectory: homeDirectory)
  }

  func uninstall(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard
      Bundle.main.bundleURL.standardizedFileURL
        == plan.installedApplicationURL.standardizedFileURL
    else {
      completion(
        .failure(AppUninstallerError.notInstalledInApplications)
      )
      return
    }

    switch autoLaunchController.setEnabled(false) {
    case .failure(let error):
      completion(.failure(error))
    case .success:
      proxyController.removeConfiguration {
        [weak self] result in
        guard let self else { return }
        switch result {
        case .failure(let error):
          completion(.failure(error))
        case .success:
          self.deactivateExtension(completion: completion)
        }
      }
    }
  }

  private func deactivateExtension(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    systemExtensionController.deactivate {
      [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success:
        self.removeFiles(completion: completion)
      }
    }
  }

  private func removeFiles(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    var errorInfo: NSDictionary?
    let appleScript = plan.privilegedRemovalAppleScript(
      waitingForProcessIdentifier:
        ProcessInfo.processInfo.processIdentifier
    )
    guard
      NSAppleScript(source: appleScript)?
        .executeAndReturnError(&errorInfo) != nil
    else {
      completion(
        .failure(
          AppUninstallerError
            .removalFailedAfterExtensionDeactivation
        )
      )
      return
    }

    removeOwnedDesktopShortcut()
    UserDefaults.standard.removePersistentDomain(
      forName: AppIdentity.bundleIdentifier
    )
    UserDefaults.standard.synchronize()
    completion(.success(()))
  }

  private func removeOwnedDesktopShortcut() {
    let shortcutPath = plan.desktopShortcutURL.path
    guard
      let destination =
        try? fileManager
        .destinationOfSymbolicLink(atPath: shortcutPath)
    else {
      return
    }

    let destinationURL: URL
    if destination.hasPrefix("/") {
      destinationURL = URL(fileURLWithPath: destination)
    } else {
      destinationURL = plan.desktopShortcutURL
        .deletingLastPathComponent()
        .appendingPathComponent(destination)
    }

    guard plan.ownsDesktopShortcut(destination: destinationURL)
    else {
      return
    }
    try? fileManager.removeItem(at: plan.desktopShortcutURL)
  }
}
