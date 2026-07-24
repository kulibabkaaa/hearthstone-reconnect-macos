import AppKit
import Foundation

enum NativeHearthstoneIdentity {
  static let bundleIdentifier = "unity.Blizzard Entertainment.Hearthstone"
  static let teamIdentifier = "G847MC6JZ5"
  static let executableSuffix = "/Hearthstone.app/Contents/MacOS/Hearthstone"
}

struct NativeHearthstoneProcess: Equatable {
  let pid: pid_t
  let executablePath: String
  let logsRoot: String
}

struct GameEndpoint: Equatable {
  let ip: String
  let port: Int
}

struct GameConnection: Equatable {
  let localIP: String
  let localPort: Int
  let remoteIP: String
  let remotePort: Int
}

enum NativeHearthstoneError: Error, CustomStringConvertible {
  case appNotRunning
  case multipleInstances
  case invalidExecutable(String)
  case noBattlegroundsConnection
  case endpointMismatch(GameEndpoint)
  case ambiguousBattlegroundsConnections(Int)

  var description: String {
    switch self {
    case .appNotRunning:
      return "Native Hearthstone is not running."
    case .multipleInstances:
      return "Multiple native Hearthstone instances are running; refusing an ambiguous target."
    case .invalidExecutable(let path):
      return "Native Hearthstone executable is invalid: \(path)"
    case .noBattlegroundsConnection:
      return "No active native Hearthstone Battlegrounds TCP/3724 connection was found."
    case .endpointMismatch(let endpoint):
      return
        "Native Hearthstone log endpoint \(endpoint.ip):\(endpoint.port) does not match an established socket owned by the game."
    case .ambiguousBattlegroundsConnections(let count):
      return
        "Found \(count) native Hearthstone TCP/3724 connections without a usable log endpoint; refusing an ambiguous target."
    }
  }
}

func isNativeHearthstoneExecutable(_ path: String) -> Bool {
  URL(fileURLWithPath: path).standardizedFileURL.path.hasSuffix(
    NativeHearthstoneIdentity.executableSuffix)
}

func nativeLogsRoot(forExecutablePath path: String) throws -> String {
  guard isNativeHearthstoneExecutable(path) else {
    throw NativeHearthstoneError.invalidExecutable(path)
  }

  let executable = URL(fileURLWithPath: path).standardizedFileURL
  let appBundle =
    executable
    .deletingLastPathComponent()  // MacOS
    .deletingLastPathComponent()  // Contents
    .deletingLastPathComponent()  // Hearthstone.app
  return
    appBundle
    .deletingLastPathComponent()
    .appendingPathComponent("Logs", isDirectory: true)
    .path
}

func runningNativeHearthstoneProcess() throws -> NativeHearthstoneProcess {
  let matches = NSRunningApplication.runningApplications(
    withBundleIdentifier: NativeHearthstoneIdentity.bundleIdentifier
  ).filter { !$0.isTerminated && $0.processIdentifier > 0 }

  guard !matches.isEmpty else { throw NativeHearthstoneError.appNotRunning }
  guard matches.count == 1 else { throw NativeHearthstoneError.multipleInstances }
  guard let executablePath = matches[0].executableURL?.path,
    isNativeHearthstoneExecutable(executablePath)
  else {
    throw NativeHearthstoneError.invalidExecutable(matches[0].executableURL?.path ?? "unknown")
  }

  return NativeHearthstoneProcess(
    pid: matches[0].processIdentifier,
    executablePath: executablePath,
    logsRoot: try nativeLogsRoot(forExecutablePath: executablePath)
  )
}

func selectNativeGameConnection(
  connections: [GameConnection],
  loggedEndpoint: GameEndpoint?
) throws -> GameConnection {
  if let loggedEndpoint {
    let matches = connections.filter {
      $0.remoteIP == loggedEndpoint.ip && $0.remotePort == loggedEndpoint.port
    }
    guard matches.count == 1 else {
      throw NativeHearthstoneError.endpointMismatch(loggedEndpoint)
    }
    return matches[0]
  }

  let gameConnections = connections.filter { $0.remotePort == 3724 }
  guard !gameConnections.isEmpty else {
    throw NativeHearthstoneError.noBattlegroundsConnection
  }
  guard gameConnections.count == 1 else {
    throw NativeHearthstoneError.ambiguousBattlegroundsConnections(gameConnections.count)
  }
  return gameConnections[0]
}
