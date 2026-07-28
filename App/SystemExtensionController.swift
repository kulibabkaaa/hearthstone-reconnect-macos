import Foundation
import SystemExtensions

enum SystemExtensionActivationResult {
  case activated
  case requiresReboot
}

final class SystemExtensionController:
  NSObject, OSSystemExtensionRequestDelegate
{
  var onApprovalRequired: (() -> Void)?

  private var completion: ((Result<SystemExtensionActivationResult, Error>) -> Void)?
  private var request: OSSystemExtensionRequest?

  func activate(
    completion: @escaping (Result<SystemExtensionActivationResult, Error>) -> Void
  ) {
    guard self.completion == nil else { return }

    self.completion = completion
    let request = OSSystemExtensionRequest.activationRequest(
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
    onApprovalRequired?()
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
    let value: SystemExtensionActivationResult =
      result == .willCompleteAfterReboot
      ? .requiresReboot
      : .activated
    finish(.success(value))
  }

  func request(
    _ request: OSSystemExtensionRequest,
    didFailWithError error: Error
  ) {
    finish(.failure(error))
  }

  private func finish(
    _ result:
      Result<SystemExtensionActivationResult, Error>
  ) {
    let completion = self.completion
    self.completion = nil
    request = nil
    completion?(result)
  }
}
