import Foundation
import Testing

@testable import ProxyCore

@Suite("Proxy core")
struct ProxyCoreTests {
  private let matcher = HearthstoneFlowMatcher()

  @Test("matches only native Hearthstone game flows")
  func matchesNativeGameFlow() {
    #expect(
      matcher.matches(
        FlowDescriptor(
          sourceSigningIdentifier:
            ProxyConstants.hearthstoneSigningIdentifier,
          remoteHost: "5.42.176.180",
          remotePort: ProxyConstants.gamePort
        )
      )
    )
  }

  @Test("rejects another app on the game port")
  func rejectsAnotherApp() {
    #expect(
      !matcher.matches(
        FlowDescriptor(
          sourceSigningIdentifier: "com.example.OtherApp",
          remoteHost: "5.42.176.180",
          remotePort: ProxyConstants.gamePort
        )
      )
    )
  }

  @Test("matches the current Hearthstone 1119 game endpoint")
  func matchesCurrentGamePort() {
    #expect(
      matcher.matches(
        FlowDescriptor(
          sourceSigningIdentifier:
            ProxyConstants.hearthstoneSigningIdentifier,
          remoteHost: "5.42.176.180",
          remotePort: 1119
        )
      )
    )
  }

  @Test("matches a logged Hearthstone endpoint on a changed port")
  func matchesChangedGamePort() {
    #expect(
      matcher.matches(
        FlowDescriptor(
          sourceSigningIdentifier:
            ProxyConstants.hearthstoneSigningIdentifier,
          remoteHost: "5.42.176.180",
          remotePort: 45678
        )
      )
    )
  }

  @Test("reconnect command round trips")
  func commandRoundTrip() {
    let command = ProviderCommand.reconnect(
      target: .exact(
        GameEndpoint(host: "5.42.176.180", port: 1119)
      )
    )
    #expect(
      ProviderCommand.decode(command.encoded) == command
    )
  }

  @Test("malformed commands are rejected")
  func malformedCommand() {
    #expect(
      ProviderCommand.decode(Data("unknown".utf8)) == nil
    )
  }

  @Test("response reports whether a flow closed")
  func responseState() {
    #expect(!ReconnectResponse(closedFlowCount: 0).didCloseFlow)
    #expect(ReconnectResponse(closedFlowCount: 2).didCloseFlow)
  }

  @Test("exact endpoint selects only the logged game flow")
  func exactEndpointSelection() {
    let flows = [
      FlowDescriptor(
        sourceSigningIdentifier:
          ProxyConstants.hearthstoneSigningIdentifier,
        remoteHost: "35.204.5.248",
        remotePort: 1119
      ),
      FlowDescriptor(
        sourceSigningIdentifier:
          ProxyConstants.hearthstoneSigningIdentifier,
        remoteHost: "5.42.176.180",
        remotePort: 1119
      ),
      FlowDescriptor(
        sourceSigningIdentifier:
          ProxyConstants.hearthstoneSigningIdentifier,
        remoteHost: "37.244.26.100",
        remotePort: 3724
      ),
    ]

    #expect(
      ReconnectTargetSelector.indices(
        in: flows,
        target: .exact(
          GameEndpoint(host: "5.42.176.180", port: 1119)
        )
      ) == [1]
    )
  }

  @Test("3724 fallback refuses an ambiguous target")
  func ambiguousFallback() {
    let flows = [
      FlowDescriptor(
        sourceSigningIdentifier:
          ProxyConstants.hearthstoneSigningIdentifier,
        remoteHost: "37.244.26.100",
        remotePort: 3724
      ),
      FlowDescriptor(
        sourceSigningIdentifier:
          ProxyConstants.hearthstoneSigningIdentifier,
        remoteHost: "37.244.26.101",
        remotePort: 3724
      ),
    ]

    #expect(
      ReconnectTargetSelector.indices(
        in: flows,
        target: .uniquePort(3724)
      ).isEmpty
    )
  }

  @Test("uses the latest valid game endpoint from the log")
  func latestLoggedEndpoint() {
    let log = """
      Network.GotoGameServe() - address= 35.204.5.248:3724
      unrelated line
      Network.GotoGameServe() - address= 5.42.176.180:1119
      """

    #expect(
      GameLogEndpointParser.latestEndpoint(in: log)
        == GameEndpoint(host: "5.42.176.180", port: 1119)
    )
  }

  @Test("parses a real GameNetLogger endpoint with trailing fields")
  func realGameNetLoggerEndpoint() {
    let log = """
      I 18:29:55.7872050 Network.GotoGameServe() - address= 5.42.176.73:1119, game=12, client=12345678, spectateKey=ABCDEF reconnecting=False
      """

    #expect(
      GameLogEndpointParser.latestEndpoint(in: log)
        == GameEndpoint(host: "5.42.176.73", port: 1119)
    )
  }

  @Test("rejects private or malformed logged endpoints")
  func rejectsUnsafeLoggedEndpoint() {
    #expect(
      GameLogEndpointParser.latestEndpoint(
        in:
          "Network.GotoGameServe() - address= 192.168.1.8:1119"
      ) == nil
    )
    #expect(
      GameLogEndpointParser.latestEndpoint(
        in: "Network.GotoGameServe() - address= not-an-ip:1119"
      ) == nil
    )
  }

  @Test("cooldown never becomes negative")
  func cooldown() {
    #expect(
      ReconnectCooldown.remaining(
        lastReconnectAt: 100,
        now: 102
      ) == 3
    )
    #expect(
      ReconnectCooldown.remaining(
        lastReconnectAt: 100,
        now: 108
      ) == 0
    )
  }
}
