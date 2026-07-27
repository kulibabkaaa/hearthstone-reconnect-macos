import AppKit
import Foundation

enum DesktopShortcutError: Error {
  case customIconCouldNotBeSet
}

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
      if let resolvedURL = try? URL(
        resolvingAliasFileAt: shortcutURL,
        options: [.withoutUI]
      ),
        resolvedURL.resolvingSymlinksInPath().standardizedFileURL
          == applicationURL.resolvingSymlinksInPath().standardizedFileURL
      {
        try setCustomIcon(
          applicationURL: applicationURL,
          shortcutURL: shortcutURL
        )
      }
      return false
    }

    let bookmarkData = try applicationURL.bookmarkData(
      options: [.suitableForBookmarkFile],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    try URL.writeBookmarkData(bookmarkData, to: shortcutURL)
    do {
      try setCustomIcon(
        applicationURL: applicationURL,
        shortcutURL: shortcutURL
      )
    } catch {
      try? fileManager.removeItem(at: shortcutURL)
      throw error
    }
    return true
  }

  private static func setCustomIcon(
    applicationURL: URL,
    shortcutURL: URL
  ) throws {
    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    guard NSWorkspace.shared.setIcon(
      icon,
      forFile: shortcutURL.path,
      options: []
    ) else {
      throw DesktopShortcutError.customIconCouldNotBeSet
    }
  }
}
