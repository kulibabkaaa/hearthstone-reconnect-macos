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
        try ensurePrivateDirectory(at: directoryURL)
        let logURL = directoryURL.appendingPathComponent(
          "\(dailyDateString()).log"
        )
        try ensurePrivateLogFile(at: logURL)

        let safeMessage = boundedLogMessage(
          redactSensitiveNetworkDetails(message)
        )
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

  static func ensurePrivateDirectory(at url: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      let attributes = try fileManager.attributesOfItem(
        atPath: url.path
      )
      guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else {
        throw CocoaError(.fileWriteNoPermission)
      }
    } else {
      try fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
    }
    try fileManager.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: url.path
    )
  }

  static func ensurePrivateLogFile(at url: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      let attributes = try fileManager.attributesOfItem(
        atPath: url.path
      )
      guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else {
        throw CocoaError(.fileWriteNoPermission)
      }
    } else {
      guard fileManager.createFile(
        atPath: url.path,
        contents: nil,
        attributes: [.posixPermissions: 0o600]
      ) else {
        throw CocoaError(.fileWriteUnknown)
      }
    }
    try fileManager.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: url.path
    )
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

func boundedLogMessage(_ message: String) -> String {
  String(message.prefix(16_000))
}
