import XCTest

@testable import HSReconnect

final class NativeHearthstoneTests: XCTestCase {
  func testNativeIdentityUsesBlizzardBundleAndTeamIdentifiers() {
    XCTAssertEqual(
      NativeHearthstoneIdentity.bundleIdentifier, "unity.Blizzard Entertainment.Hearthstone")
    XCTAssertEqual(NativeHearthstoneIdentity.teamIdentifier, "G847MC6JZ5")
  }

  func testNativeExecutablePathAcceptsOnlyHearthstoneAppExecutable() {
    XCTAssertTrue(
      isNativeHearthstoneExecutable(
        "/Applications/Hearthstone/Hearthstone.app/Contents/MacOS/Hearthstone"))
    XCTAssertFalse(
      isNativeHearthstoneExecutable("/Applications/Battle.net.app/Contents/MacOS/Battle.net"))
    XCTAssertFalse(isNativeHearthstoneExecutable("/CrossOver/Hearthstone.exe"))
  }

  func testDerivesLogsBesideNativeAppBundle() throws {
    let executable = "/Applications/Hearthstone/Hearthstone.app/Contents/MacOS/Hearthstone"
    XCTAssertEqual(
      try nativeLogsRoot(forExecutablePath: executable), "/Applications/Hearthstone/Logs")
  }

  func testSelectsExactLoggedGameEndpointOnCurrent1119Port() throws {
    let connections = [
      GameConnection(
        localIP: "192.168.4.138", localPort: 50000, remoteIP: "35.204.5.248", remotePort: 1119),
      GameConnection(
        localIP: "192.168.4.138", localPort: 50002, remoteIP: "5.42.176.180", remotePort: 1119),
      GameConnection(
        localIP: "192.168.4.138", localPort: 50001, remoteIP: "37.244.26.100", remotePort: 3724),
    ]

    let selected = try selectNativeGameConnection(
      connections: connections,
      loggedEndpoint: GameEndpoint(ip: "5.42.176.180", port: 1119)
    )

    XCTAssertEqual(selected.remotePort, 1119)
    XCTAssertEqual(selected.remoteIP, "5.42.176.180")
  }

  func testFallbackSelectsOnlyUnique3724Connection() throws {
    let connections = [
      GameConnection(
        localIP: "192.168.4.138", localPort: 50000, remoteIP: "34.13.1.1", remotePort: 1119),
      GameConnection(
        localIP: "192.168.4.138", localPort: 50001, remoteIP: "37.244.26.100", remotePort: 3724),
    ]

    let selected = try selectNativeGameConnection(connections: connections, loggedEndpoint: nil)
    XCTAssertEqual(selected.remotePort, 3724)
  }

  func testRejectsAmbiguous3724Fallback() {
    let connections = [
      GameConnection(
        localIP: "192.168.4.138", localPort: 50001, remoteIP: "37.244.26.100", remotePort: 3724),
      GameConnection(
        localIP: "192.168.4.138", localPort: 50002, remoteIP: "37.244.26.101", remotePort: 3724),
    ]

    XCTAssertThrowsError(
      try selectNativeGameConnection(connections: connections, loggedEndpoint: nil))
  }

  func testNeverFallsBackToAuthenticationOrHTTPS() {
    let connections = [
      GameConnection(
        localIP: "192.168.4.138", localPort: 50000, remoteIP: "34.13.1.1", remotePort: 1119),
      GameConnection(
        localIP: "192.168.4.138", localPort: 50003, remoteIP: "137.221.1.1", remotePort: 443),
    ]

    XCTAssertThrowsError(
      try selectNativeGameConnection(connections: connections, loggedEndpoint: nil))
  }

}
