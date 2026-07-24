import Foundation

enum AppLog {
  private static let queue = DispatchQueue(label: "HSReconnect.AppLog")

  static var directoryURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent(AppConfiguration.appName, isDirectory: true)
  }

  static func prepare() {
    queue.async {
      pruneExpiredLogs()
    }
  }

  static func write(_ message: String) {
    queue.async {
      do {
        try FileManager.default.createDirectory(
          at: directoryURL,
          withIntermediateDirectories: true
        )
        let logURL = directoryURL.appendingPathComponent(
          "\(dailyDateString()).log"
        )
        if !FileManager.default.fileExists(atPath: logURL.path) {
          FileManager.default.createFile(
            atPath: logURL.path,
            contents: nil
          )
        }

        let safeMessage = redactSensitiveNetworkDetails(message)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(safeMessage)\n"
        guard let data = line.data(using: .utf8) else { return }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
      } catch {
        NSLog("HS Reconnect log write failed")
      }
    }
  }

  private static func dailyDateString() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private static func pruneExpiredLogs() {
    let keys: Set<URLResourceKey> = [
      .contentModificationDateKey,
      .isRegularFileKey,
    ]
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: Array(keys)
      )
    else {
      return
    }

    for file in files where file.pathExtension == "log" {
      guard let values = try? file.resourceValues(forKeys: keys),
        values.isRegularFile == true,
        let modifiedAt = values.contentModificationDate,
        shouldRemoveLog(modifiedAt: modifiedAt)
      else {
        continue
      }
      try? FileManager.default.removeItem(at: file)
    }
  }
}
