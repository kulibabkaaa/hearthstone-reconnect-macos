import Foundation
import CryptoKit

struct AppError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

final class ReconnectService {
  private(set) var isRunning = false

  private func bundledHelperPath() -> String? {
    guard let resourcePath = Bundle.main.resourcePath else { return nil }
    return URL(fileURLWithPath: resourcePath)
      .appendingPathComponent("hsreconnect-helper")
      .path
  }

  func helperInstallIssue() -> String? {
    guard
      FileManager.default.isExecutableFile(
        atPath: AppConfiguration.installedHelperPath
      )
    else {
      return "helper is not installed"
    }

    if privilegedFileIssue(
      atPath: AppConfiguration.installedHelperPath,
      expectedPermissions: 0o755,
      ownerID: 0,
      groupID: 0
    ) != nil {
      return "helper permissions are invalid"
    }

    if privilegedFileIssue(
      atPath: AppConfiguration.sudoersPath,
      expectedPermissions: 0o440,
      ownerID: 0,
      groupID: 0
    ) != nil {
      return "helper permission is missing or invalid"
    }

    guard let bundledHelperPath = bundledHelperPath(),
      let bundledData = FileManager.default.contents(
        atPath: bundledHelperPath
      ),
      let installedData = FileManager.default.contents(
        atPath: AppConfiguration.installedHelperPath
      ),
      let sudoersData = FileManager.default.contents(
        atPath: AppConfiguration.sudoersPath
      )
    else {
      return "helper could not be verified"
    }

    guard bundledData == installedData else {
      return "helper update is required"
    }
    let expectedEntry = expectedSudoersEntry(
      user: NSUserName(),
      helperData: installedData
    )
    let sudoersEntries = String(
      decoding: sudoersData,
      as: UTF8.self
    ).split(whereSeparator: \.isNewline)
    guard sudoersEntries.contains(Substring(expectedEntry)) else {
      return "helper permission is out of date"
    }
    return nil
  }

  func reconnect(
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard !isRunning else {
      completion(.failure(AppError("Reconnect already running.")))
      return
    }

    if let issue = helperInstallIssue() {
      completion(.failure(AppError("Helper problem: \(issue).")))
      return
    }

    let target: NativeHearthstoneProcess
    do {
      target = try runningNativeHearthstoneProcess()
    } catch {
      completion(.failure(error))
      return
    }

    isRunning = true
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let processResult = try runProcessCapturingCombinedOutput(
          executableURL: URL(fileURLWithPath: "/usr/bin/sudo"),
          arguments: [
            "-n",
            AppConfiguration.installedHelperPath,
            "--pid",
            String(target.pid),
            "--executable",
            target.executablePath,
            "--logs-root",
            target.logsRoot,
            "--rst",
          ]
        )
        let combined = processResult.output
          .trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
          self.isRunning = false
          if processResult.status == 0 {
            completion(.success(combined))
          } else {
            completion(.failure(AppError(combined)))
          }
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunning = false
          completion(.failure(error))
        }
      }
    }
  }
}

func expectedSudoersEntry(
  user: String,
  helperData: Data
) -> String {
  let digest = SHA256.hash(data: helperData)
    .map { String(format: "%02x", $0) }
    .joined()
  return
    "\(user) ALL=(root) NOPASSWD: sha256:\(digest) "
    + AppConfiguration.installedHelperPath
}

struct ProcessOutput {
  let status: Int32
  let output: String
}

func runProcessCapturingCombinedOutput(
  executableURL: URL,
  arguments: [String]
) throws -> ProcessOutput {
  let outputPipe = Pipe()
  let process = Process()
  process.executableURL = executableURL
  process.arguments = arguments
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try process.run()
  let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  return ProcessOutput(
    status: process.terminationStatus,
    output: String(decoding: outputData, as: UTF8.self)
  )
}

func privilegedFileIssue(
  atPath path: String,
  expectedPermissions: Int,
  ownerID: Int,
  groupID: Int
) -> String? {
  guard
    let attributes = try? FileManager.default.attributesOfItem(
      atPath: path
    )
  else {
    return "file is missing"
  }
  guard attributes[.type] as? FileAttributeType == .typeRegular else {
    return "file is not regular"
  }
  guard
    (attributes[.ownerAccountID] as? NSNumber)?.intValue == ownerID,
    (attributes[.groupOwnerAccountID] as? NSNumber)?.intValue == groupID
  else {
    return "file ownership is invalid"
  }
  let permissions =
    (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
  guard permissions & 0o7777 == expectedPermissions else {
    return "file permissions are invalid"
  }
  return nil
}

func helperTouchedNetwork(_ message: String) -> Bool {
  helperNetworkTouchTimestamp(message) != nil || message.contains("PF rules loaded:")
    || message.contains("PF state cleanup:") || message.contains("Socket turnover observed")
    || message.contains("Socket dropped but") || message.contains("No local TCP reset observed")
}

func helperNetworkTouchTimestamp(_ message: String) -> TimeInterval? {
  let prefix = "HSRECONNECT_NETWORK_TOUCHED_AT="
  for line in message.split(whereSeparator: \.isNewline) {
    guard line.hasPrefix(prefix),
      let value = TimeInterval(line.dropFirst(prefix.count)),
      value.isFinite,
      value > 0
    else {
      continue
    }
    return value
  }
  return nil
}
