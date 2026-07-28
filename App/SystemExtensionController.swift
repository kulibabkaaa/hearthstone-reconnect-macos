import Foundation
import SystemExtensions

enum SystemExtensionActivationResult {
  case activated
  case requiresReboot
}

enum SystemExtensionDeactivationResult {
  case deactivated
  case requiresReboot
}

final class SystemExtensionController:
  NSObject, OSSystemExtensionRequestDelegate
{
  var onApprovalRequired: (() -> Void)?
  var onDeactivationApprovalRequired: (() -> Void)?

  private enum Operation {
    case activation(
      (Result<SystemExtensionActivationResult, Error>) -> Void
    )
    case deactivation(
      (Result<SystemExtensionDeactivationResult, Error>) -> Void
    )
  }

  private var operation: Operation?
  private var pendingDeactivation: ((Result<SystemExtensionDeactivationResult, Error>) -> Void)?
  private var request: OSSystemExtensionRequest?

  func activate(
    completion: @escaping (Result<SystemExtensionActivationResult, Error>) -> Void
  ) {
    guard operation == nil else { return }

    operation = .activation(completion)
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier:
        AppConfiguration.extensionBundleIdentifier,
      queue: .main
    )
    request.delegate = self
    self.request = request
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  func deactivate(
    completion:
      @escaping (Result<SystemExtensionDeactivationResult, Error>) -> Void
  ) {
    guard operation == nil else {
      pendingDeactivation = completion
      return
    }

    operation = .deactivation(completion)
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier:
        AppConfiguration.extensionBundleIdentifier,
      queue: .main
    )
    request.delegate = self
    self.request = request
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  func requestNeedsUserApproval(
    _ request: OSSystemExtensionRequest
  ) {
    switch operation {
    case .activation:
      onApprovalRequired?()
    case .deactivation:
      onDeactivationApprovalRequired?()
    case nil:
      break
    }
  }

  func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing:
      OSSystemExtensionProperties,
    withExtension ext: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    .replace
  }

  func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    guard let operation = beginFinishing() else { return }
    switch operation {
    case .activation(let completion):
      completion(
        .success(
          result == .willCompleteAfterReboot
            ? .requiresReboot
            : .activated
        )
      )
    case .deactivation(let completion):
      completion(
        .success(
          result == .willCompleteAfterReboot
            ? .requiresReboot
            : .deactivated
        )
      )
    }
    startPendingDeactivationIfNeeded()
  }

  func request(
    _ request: OSSystemExtensionRequest,
    didFailWithError error: Error
  ) {
    guard let operation = beginFinishing() else { return }
    switch operation {
    case .activation(let completion):
      completion(.failure(error))
    case .deactivation(let completion):
      if Self.isExtensionNotFound(error) {
        completion(.success(.deactivated))
      } else {
        completion(.failure(error))
      }
    }
    startPendingDeactivationIfNeeded()
  }

  private func beginFinishing() -> Operation? {
    let operation = self.operation
    self.operation = nil
    request = nil
    return operation
  }

  private func startPendingDeactivationIfNeeded() {
    if let pendingDeactivation {
      self.pendingDeactivation = nil
      deactivate(completion: pendingDeactivation)
    }
  }

  private static func isExtensionNotFound(
    _ error: Error
  ) -> Bool {
    let error = error as NSError
    return error.domain == OSSystemExtensionErrorDomain
      && error.code
        == OSSystemExtensionError.Code.extensionNotFound.rawValue
  }
}
