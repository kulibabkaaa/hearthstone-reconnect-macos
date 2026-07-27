import Foundation

enum DesktopShortcutInstaller {
  @discardableResult
  static func createAliasIfNeeded(
    applicationURL: URL,
    shortcutURL: URL,
    fileManager: FileManager = .default
  ) throws -> Bool {
    if fileManager.fileExists(atPath: shortcutURL.path)
      || (try? fileManager.destinationOfSymbolicLink(
        atPath: shortcutURL.path
      )) != nil
    {
      return false
    }

    let bookmarkData = try applicationURL.bookmarkData(
      options: [.suitableForBookmarkFile],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    try URL.writeBookmarkData(bookmarkData, to: shortcutURL)
    return true
  }
}
