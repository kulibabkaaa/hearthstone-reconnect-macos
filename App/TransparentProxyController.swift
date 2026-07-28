import Foundation
import NetworkExtension

enum TransparentProxyControllerError: Error {
  case configurationMissing
  case sessionUnavailable
  case startTimedOut
  case responseMissing
  case responseInvalid
}

final class TransparentProxyController {
  private var retainedManager: NETransparentProxyManager?

  func prepare(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    loadManager { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let manager):
        self.configureIfNeeded(manager) { result in
          switch result {
          case .failure(let error):
            completion(.failure(error))
          case .success(let configuredManager):
            self.retainedManager = configuredManager
            self.start(
              configuredManager,
              completion: completion
            )
          }
        }
      }
    }
  }

  func reconnect(
    target: ReconnectTarget,
    completion: @escaping (Result<ReconnectResponse, Error>) -> Void
  ) {
    loadManager { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let manager):
        self.retainedManager = manager
        self.ensureStarted(manager) { startResult in
          switch startResult {
          case .failure(let error):
            completion(.failure(error))
          case .success:
            self.sendReconnect(
              through: manager,
              target: target,
              completion: completion
            )
          }
        }
      }
    }
  }

  private func loadManager(
    completion: @escaping (Result<NETransparentProxyManager, Error>) -> Void
  ) {
    NETransparentProxyManager
      .loadAllFromPreferences { managers, error in
        DispatchQueue.main.async {
          if let error {
            completion(.failure(error))
            return
          }

          let matching = managers?.first {
            ($0.protocolConfiguration
              as? NETunnelProviderProtocol)?
              .providerBundleIdentifier
              == AppConfiguration.extensionBundleIdentifier
          }
          completion(.success(matching ?? NETransparentProxyManager()))
        }
      }
  }

  private func configureIfNeeded(
    _ manager: NETransparentProxyManager,
    completion: @escaping (Result<NETransparentProxyManager, Error>) -> Void
  ) {
    let protocolConfiguration =
      manager.protocolConfiguration as? NETunnelProviderProtocol
    let isCurrent =
      protocolConfiguration?.providerBundleIdentifier
      == AppConfiguration.extensionBundleIdentifier
      && manager.isEnabled

    guard !isCurrent else {
      completion(.success(manager))
      return
    }

    let configuration = NETunnelProviderProtocol()
    configuration.providerBundleIdentifier =
      AppConfiguration.extensionBundleIdentifier
    configuration.serverAddress = "Local Hearthstone proxy"
    configuration.providerConfiguration = [
      "gamePort": Int(ProxyConstants.gamePort)
    ]

    manager.localizedDescription = AppConfiguration.appName
    manager.protocolConfiguration = configuration
    manager.isEnabled = true
    manager.saveToPreferences { error in
      DispatchQueue.main.async {
        if let error {
          completion(.failure(error))
          return
        }
        manager.loadFromPreferences { reloadError in
          DispatchQueue.main.async {
            if let reloadError {
              completion(.failure(reloadError))
            } else {
              completion(.success(manager))
            }
          }
        }
      }
    }
  }

  private func start(
    _ manager: NETransparentProxyManager,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      if manager.connection.status != .connected
        && manager.connection.status != .connecting
      {
        try manager.connection.startVPNTunnel()
      }
      waitUntilConnected(
        manager,
        deadline: Date(timeIntervalSinceNow: 10),
        completion: completion
      )
    } catch {
      completion(.failure(error))
    }
  }

  private func ensureStarted(
    _ manager: NETransparentProxyManager,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if manager.connection.status == .connected {
      completion(.success(()))
      return
    }
    start(manager, completion: completion)
  }

  private func waitUntilConnected(
    _ manager: NETransparentProxyManager,
    deadline: Date,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if manager.connection.status == .connected {
      completion(.success(()))
      return
    }
    guard Date() < deadline else {
      completion(
        .failure(TransparentProxyControllerError.startTimedOut)
      )
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      [weak self] in
      self?.waitUntilConnected(
        manager,
        deadline: deadline,
        completion: completion
      )
    }
  }

  private func sendReconnect(
    through manager: NETransparentProxyManager,
    target: ReconnectTarget,
    completion: @escaping (Result<ReconnectResponse, Error>) -> Void
  ) {
    guard
      let session = manager.connection
        as? NETunnelProviderSession
    else {
      completion(
        .failure(TransparentProxyControllerError.sessionUnavailable)
      )
      return
    }

    do {
      try session.sendProviderMessage(
        ProviderCommand.reconnect(target: target).encoded
      ) { data in
        DispatchQueue.main.async {
          guard let data else {
            completion(
              .failure(
                TransparentProxyControllerError.responseMissing
              )
            )
            return
          }
          do {
            completion(
              .success(
                try JSONDecoder().decode(
                  ReconnectResponse.self,
                  from: data
                )
              )
            )
          } catch {
            completion(
              .failure(
                TransparentProxyControllerError.responseInvalid
              )
            )
          }
        }
      }
    } catch {
      completion(.failure(error))
    }
  }
}
