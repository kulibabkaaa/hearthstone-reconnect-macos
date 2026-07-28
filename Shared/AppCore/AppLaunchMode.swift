import Foundation

public enum AppLaunchMode: Equatable, Sendable {
  public static let resumeUninstallArgument =
    "--resume-uninstall-after-pid"

  case normal(launchedForHearthstone: Bool)
  case resumeUninstall(waitingForProcessIdentifier: Int32)

  public init(arguments: [String]) {
    if let argumentIndex = arguments.firstIndex(
      of: Self.resumeUninstallArgument
    ),
      arguments.indices.contains(argumentIndex + 1),
      let processIdentifier = Int32(
        arguments[argumentIndex + 1]
      ),
      processIdentifier > 0
    {
      self = .resumeUninstall(
        waitingForProcessIdentifier: processIdentifier
      )
      return
    }

    self = .normal(
      launchedForHearthstone:
        arguments.contains("--from-hearthstone")
    )
  }

  public var launchedForHearthstone: Bool {
    guard
      case .normal(let launchedForHearthstone) = self
    else {
      return false
    }
    return launchedForHearthstone
  }

  public var uninstallProcessIdentifier: Int32? {
    guard
      case .resumeUninstall(
        let waitingForProcessIdentifier
      ) = self
    else {
      return nil
    }
    return waitingForProcessIdentifier
  }
}
