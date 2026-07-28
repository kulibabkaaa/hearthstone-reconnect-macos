import Foundation
import Network
import NetworkExtension

final class TCPFlowRelay {
  private let flow: NEAppProxyTCPFlow
  private let connection: NWConnection
  private let queue: DispatchQueue
  private let onFinish: () -> Void

  private var isFinished = false
  private var isFlowOpen = false

  init?(
    flow: NEAppProxyTCPFlow,
    queue: DispatchQueue,
    onFinish: @escaping () -> Void
  ) {
    guard
      let endpoint = flow.remoteEndpoint as? NWHostEndpoint,
      let port = NWEndpoint.Port(endpoint.port)
    else {
      return nil
    }

    let parameters = NWParameters.tcp
    if #available(macOS 15.0, *) {
      flow.setMetadata(on: parameters)
    }

    self.flow = flow
    self.connection = NWConnection(
      host: NWEndpoint.Host(endpoint.hostname),
      port: port,
      using: parameters
    )
    self.queue = queue
    self.onFinish = onFinish
  }

  func start() {
    connection.stateUpdateHandler = { [weak self] state in
      self?.handleConnectionState(state)
    }
    connection.start(queue: queue)
  }

  @discardableResult
  func closeForReconnect() -> Bool {
    guard !isFinished else { return false }
    let error = NSError(
      domain: NEAppProxyErrorDomain,
      code: NEAppProxyFlowError.aborted.rawValue
    )
    finish(error: error)
    return true
  }

  private func handleConnectionState(
    _ state: NWConnection.State
  ) {
    switch state {
    case .ready:
      openFlow()
    case .failed(let error):
      finish(error: error)
    case .cancelled:
      finish(error: nil)
    case .setup, .preparing, .waiting:
      break
    @unknown default:
      finish(error: nil)
    }
  }

  private func openFlow() {
    guard !isFinished, !isFlowOpen else { return }
    isFlowOpen = true
    flow.open(withLocalEndpoint: nil) {
      [weak self] error in
      guard let self else { return }
      self.queue.async {
        if let error {
          self.finish(error: error)
          return
        }
        self.copyInbound()
        self.copyOutbound()
      }
    }
  }

  private func copyInbound() {
    guard !isFinished else { return }
    connection.receive(
      minimumIncompleteLength: 1,
      maximumLength: 64 * 1024
    ) { [weak self] data, _, isComplete, error in
      guard let self else { return }
      self.queue.async {
        guard !self.isFinished else { return }

        if let data, !data.isEmpty {
          self.flow.write(data) { [weak self] writeError in
            guard let self else { return }
            self.queue.async {
              if let writeError {
                self.finish(error: writeError)
              } else if isComplete {
                self.finish(error: error)
              } else {
                self.copyInbound()
              }
            }
          }
        } else if isComplete || error != nil {
          self.finish(error: error)
        } else {
          self.copyInbound()
        }
      }
    }
  }

  private func copyOutbound() {
    guard !isFinished else { return }
    flow.readData { [weak self] data, error in
      guard let self else { return }
      self.queue.async {
        guard !self.isFinished else { return }
        guard error == nil, let data, !data.isEmpty else {
          self.finish(error: error)
          return
        }

        self.connection.send(
          content: data,
          completion: .contentProcessed { [weak self] sendError in
            guard let self else { return }
            self.queue.async {
              if let sendError {
                self.finish(error: sendError)
              } else {
                self.copyOutbound()
              }
            }
          }
        )
      }
    }
  }

  private func finish(error: Error?) {
    guard !isFinished else { return }
    isFinished = true
    connection.stateUpdateHandler = nil
    connection.cancel()
    flow.closeReadWithError(error)
    flow.closeWriteWithError(error)
    onFinish()
  }
}
