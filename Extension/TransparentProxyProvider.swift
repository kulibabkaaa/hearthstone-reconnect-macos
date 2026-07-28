import Foundation
import NetworkExtension

final class TransparentProxyProvider:
  NETransparentProxyProvider
{
  private struct TrackedRelay {
    let descriptor: FlowDescriptor
    let relay: TCPFlowRelay
  }

  private let queue = DispatchQueue(
    label:
      "io.github.kulibabkaaa.HSReconnect.ProxyExtension"
  )
  private let matcher = HearthstoneFlowMatcher()
  private var activeRelays: [UUID: TrackedRelay] = [:]
  private var isStarted = false

  override func startProxy(
    options: [String: Any]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    queue.async {
      guard !self.isStarted else {
        completionHandler(nil)
        return
      }
      self.isStarted = true

      let settings = NETransparentProxyNetworkSettings(
        tunnelRemoteAddress: "127.0.0.1"
      )
      settings.includedNetworkRules = [
        NENetworkRule(
          remoteNetwork: nil,
          remotePrefix: 0,
          localNetwork: nil,
          localPrefix: 0,
          protocol: .TCP,
          direction: .outbound
        )
      ]

      self.setTunnelNetworkSettings(settings) { error in
        self.queue.async {
          if error != nil {
            self.isStarted = false
          }
          completionHandler(error)
        }
      }
    }
  }

  override func stopProxy(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    queue.async {
      let relays = Array(self.activeRelays.values)
      for trackedRelay in relays {
        _ = trackedRelay.relay.closeForReconnect()
      }
      self.activeRelays.removeAll()
      self.isStarted = false
      completionHandler()
    }
  }

  override func handleNewFlow(
    _ flow: NEAppProxyFlow
  ) -> Bool {
    guard
      let tcpFlow = flow as? NEAppProxyTCPFlow,
      let endpoint = tcpFlow.remoteEndpoint as? NWHostEndpoint,
      let port = UInt16(endpoint.port),
      port > 0
    else {
      return false
    }

    let descriptor = FlowDescriptor(
      sourceSigningIdentifier:
        flow.metaData.sourceAppSigningIdentifier,
      remoteHost: endpoint.hostname,
      remotePort: port
    )
    guard matcher.matches(descriptor) else {
      return false
    }

    let identifier = UUID()
    guard
      let relay = TCPFlowRelay(
        flow: tcpFlow,
        queue: queue,
        onFinish: { [weak self] in
          self?.activeRelays.removeValue(forKey: identifier)
        }
      )
    else {
      return false
    }

    queue.async {
      self.activeRelays[identifier] = TrackedRelay(
        descriptor: descriptor,
        relay: relay
      )
      relay.start()
    }
    return true
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    queue.async {
      guard
        case .reconnect(let target) =
          ProviderCommand.decode(messageData)
      else {
        completionHandler?(nil)
        return
      }

      let relays = Array(self.activeRelays.values)
      let matchingIndices = ReconnectTargetSelector.indices(
        in: relays.map(\.descriptor),
        target: target
      )
      let closedCount = matchingIndices.reduce(into: 0) {
        count, index in
        if relays[index].relay.closeForReconnect() {
          count += 1
        }
      }
      let response = ReconnectResponse(
        closedFlowCount: closedCount
      )
      completionHandler?(
        try? JSONEncoder().encode(response)
      )
    }
  }
}
