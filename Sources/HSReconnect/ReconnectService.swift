import Foundation

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

    guard
      FileManager.default.fileExists(
        atPath: AppConfiguration.sudoersPath
      )
    else {
      return "helper permission is missing"
    }

    guard let bundledHelperPath = bundledHelperPath(),
      let bundledData = FileManager.default.contents(
        atPath: bundledHelperPath
      ),
      let installedData = FileManager.default.contents(
        atPath: AppConfiguration.installedHelperPath
      )
    else {
      return "helper could not be verified"
    }

    guard bundledData == installedData else {
      return "helper update is required"
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
      let standardOutput = Pipe()
      let errorOutput = Pipe()
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
      process.arguments = [
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
      process.standardOutput = standardOutput
      process.standardError = errorOutput

      do {
        try process.run()
        process.waitUntilExit()
        let stdout =
          String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
          ) ?? ""
        let stderr =
          String(
            data: errorOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
          ) ?? ""
        let combined = (stderr + stdout)
          .trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
          self.isRunning = false
          if process.terminationStatus == 0 {
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
