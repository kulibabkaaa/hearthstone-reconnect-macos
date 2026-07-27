import AppKit

final class SettingsWindowController: NSWindowController {
  private let onReconnect: () -> Void
  private let onShortcutChanged: (UInt32, UInt32, String) -> Bool
  private let onOpenWithHearthstoneChanged: (Bool) -> Result<Void, Error>
  private let onShowInDockChanged: (Bool) -> Bool

  private let statusLabel = NSTextField(labelWithString: "Ready")
  private let shortcutButton = RecorderButton(
    title: "",
    target: nil,
    action: nil
  )
  private let openWithHearthstoneCheckbox = NSButton(
    checkboxWithTitle: "Open HS Reconnect with Hearthstone",
    target: nil,
    action: nil
  )
  private let showInDockCheckbox = NSButton(
    checkboxWithTitle: "Show HS Reconnect in Dock",
    target: nil,
    action: nil
  )
  private let reconnectButton = NSButton(
    title: "Reconnect Now",
    target: nil,
    action: nil
  )

  init(
    onReconnect: @escaping () -> Void,
    onShortcutChanged: @escaping (UInt32, UInt32, String) -> Bool,
    onOpenWithHearthstoneChanged: @escaping (Bool) -> Result<Void, Error>,
    onShowInDockChanged: @escaping (Bool) -> Bool
  ) {
    self.onReconnect = onReconnect
    self.onShortcutChanged = onShortcutChanged
    self.onOpenWithHearthstoneChanged = onOpenWithHearthstoneChanged
    self.onShowInDockChanged = onShowInDockChanged

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 470, height: 340),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = AppConfiguration.appName
    window.center()
    window.isReleasedWhenClosed = false

    super.init(window: window)
    buildInterface()
    refresh()
  }

  required init?(coder: NSCoder) {
    nil
  }

  func refresh() {
    shortcutButton.title =
      UserDefaults.standard.string(
        forKey: DefaultsKey.hotkeyDisplay
      ) ?? AppConfiguration.defaultShortcutDisplay
    openWithHearthstoneCheckbox.state =
      UserDefaults.standard.bool(
        forKey: DefaultsKey.openWithHearthstone
      ) ? .on : .off
    showInDockCheckbox.state =
      UserDefaults.standard.bool(
        forKey: DefaultsKey.showInDock
      ) ? .on : .off
  }

  func setStatus(_ message: String, isError: Bool = false) {
    statusLabel.stringValue = message
    statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    statusLabel.toolTip = message
    NSAccessibility.post(
      element: statusLabel,
      notification: .valueChanged
    )
  }

  func setReconnectEnabled(_ enabled: Bool) {
    reconnectButton.isEnabled = enabled
  }

  private func buildInterface() {
    guard let contentView = window?.contentView else { return }

    let title = NSTextField(labelWithString: AppConfiguration.appName)
    title.font = .systemFont(ofSize: 22, weight: .semibold)
    title.setAccessibilityRole(.staticText)

    let description = NSTextField(
      wrappingLabelWithString:
        "Use a global shortcut to reconnect to your current Battlegrounds game."
    )
    description.textColor = .secondaryLabelColor
    description.maximumNumberOfLines = 2

    shortcutButton.bezelStyle = .rounded
    shortcutButton.setAccessibilityLabel("Change global shortcut")
    shortcutButton.onValidationMessage = { [weak self] message in
      self?.setStatus(
        message,
        isError: message != "Shortcut change cancelled."
      )
    }
    shortcutButton.onRecord = { [weak self] keyCode, modifiers, display in
      guard let self else { return false }
      let changed = self.onShortcutChanged(
        keyCode,
        modifiers,
        display
      )
      if changed {
        self.setStatus("Shortcut changed to \(display).")
      } else {
        self.setStatus(
          "That shortcut is already in use. Choose another one.",
          isError: true
        )
      }
      return changed
    }

    let shortcutLabel = NSTextField(
      labelWithString: "Global shortcut"
    )
    shortcutLabel.font = .systemFont(ofSize: 13, weight: .medium)

    let shortcutSpacer = NSView()
    let shortcutRow = NSStackView(
      views: [shortcutLabel, shortcutSpacer, shortcutButton]
    )
    shortcutRow.orientation = .horizontal
    shortcutRow.alignment = .centerY
    shortcutRow.spacing = 12
    shortcutSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

    openWithHearthstoneCheckbox.target = self
    openWithHearthstoneCheckbox.action =
      #selector(openWithHearthstoneChanged)

    showInDockCheckbox.target = self
    showInDockCheckbox.action = #selector(showInDockChanged)

    reconnectButton.target = self
    reconnectButton.action = #selector(reconnectNow)
    reconnectButton.bezelStyle = .rounded
    reconnectButton.keyEquivalent = "\r"
    reconnectButton.setAccessibilityLabel("Reconnect now")

    statusLabel.textColor = .secondaryLabelColor
    statusLabel.setAccessibilityLabel("Status")
    statusLabel.lineBreakMode = .byWordWrapping
    statusLabel.maximumNumberOfLines = 2
    statusLabel.setContentCompressionResistancePriority(
      .defaultLow,
      for: .horizontal
    )

    let stack = NSStackView(
      views: [
        title,
        description,
        shortcutRow,
        openWithHearthstoneCheckbox,
        showInDockCheckbox,
        reconnectButton,
        statusLabel,
      ]
    )
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(
        equalTo: contentView.leadingAnchor,
        constant: 24
      ),
      stack.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor,
        constant: -24
      ),
      stack.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: 24
      ),
      stack.bottomAnchor.constraint(
        lessThanOrEqualTo: contentView.bottomAnchor,
        constant: -24
      ),
      shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      reconnectButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  @objc private func reconnectNow() {
    onReconnect()
  }

  @objc private func openWithHearthstoneChanged() {
    let enabled = openWithHearthstoneCheckbox.state == .on
    switch onOpenWithHearthstoneChanged(enabled) {
    case .success:
      setStatus(
        enabled
          ? "HS Reconnect will open with Hearthstone."
          : "Automatic opening is off."
      )
    case .failure:
      setStatus(
        "Automatic opening couldn't be changed. Please try again.",
        isError: true
      )
      refresh()
    }
  }

  @objc private func showInDockChanged() {
    let enabled = showInDockCheckbox.state == .on
    if onShowInDockChanged(enabled) {
      setStatus(
        enabled
          ? "HS Reconnect is shown in the Dock."
          : "HS Reconnect is hidden from the Dock. Use the menu bar icon to open it."
      )
    } else {
      setStatus(
        "Dock visibility couldn't be changed. Please try again.",
        isError: true
      )
      refresh()
    }
  }
}
