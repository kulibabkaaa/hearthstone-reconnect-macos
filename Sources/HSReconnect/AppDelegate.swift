import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let launchedForHearthstone: Bool
  private let reconnectService = ReconnectService()
  private let hotKeyManager = GlobalHotKeyManager()
  private let autoLaunchController = AutoLaunchController()
  private let dockVisibilityController = DockVisibilityController()

  private var statusItem: NSStatusItem!
  private var reconnectMenuItem: NSMenuItem!
  private var settingsWindowController: SettingsWindowController!
  private var cooldownTimer: Timer?
  private var userOpenedWindow = false

  init(launchedForHearthstone: Bool) {
    self.launchedForHearthstone = launchedForHearthstone
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let legacyAppRetired =
      LegacyApplicationMigration.terminateRunningApplications()
    registerDefaults()
    let dockPreferenceApplied =
      dockVisibilityController.applyStoredPreference()
    autoLaunchController.synchronizeStoredState()
    AppLog.prepare()
    if !dockPreferenceApplied {
      AppLog.write("Dock visibility preference could not be applied")
    }
    AppLog.write(
      launchedForHearthstone
        ? "App launched with Hearthstone"
        : "App launched manually"
    )

    buildMainMenu()
    buildMenuBar()
    settingsWindowController = SettingsWindowController(
      onReconnect: { [weak self] in
        self?.runReconnect()
      },
      onShortcutChanged: { [weak self] keyCode, modifiers, display in
        self?.changeShortcut(
          keyCode: keyCode,
          modifiers: modifiers,
          display: display
        ) ?? false
      },
      onOpenWithHearthstoneChanged: { [weak self] enabled in
        self?.autoLaunchController.setEnabled(enabled)
          ?? .failure(AutoLaunchError.unavailable)
      },
      onShowInDockChanged: { [weak self] enabled in
        self?.setShowInDock(enabled) ?? false
      }
    )

    hotKeyManager.onHotKey = { [weak self] in
      AppLog.write("Global shortcut pressed")
      self?.runReconnect()
    }
    if legacyAppRetired {
      registerStoredHotKey()
    } else {
      AppLog.write("Older reconnect app could not be closed")
      settingsWindowController.setStatus(
        "Close the older Hearthstone Reconnect app, then change the shortcut.",
        isError: true
      )
    }
    observeHearthstoneTermination()

    if !launchedForHearthstone {
      showWindow()
      configureDefaultAutoLaunch()
    }

    updateReconnectAvailability()
    cooldownTimer = Timer.scheduledTimer(
      withTimeInterval: 0.5,
      repeats: true
    ) { [weak self] _ in
      self?.updateReconnectAvailability()
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    false
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    showWindow()
    return true
  }

  func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    true
  }

  private func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      DefaultsKey.keyCode: Int(
        AppConfiguration.defaultShortcutKeyCode
      ),
      DefaultsKey.modifiers: Int(defaultCarbonModifiers()),
      DefaultsKey.hotkeyDisplay:
        AppConfiguration.defaultShortcutDisplay,
      DefaultsKey.openWithHearthstone:
        AppConfiguration.openWithHearthstoneByDefault,
      DefaultsKey.showInDock:
        AppConfiguration.showInDockByDefault,
      DefaultsKey.lastReconnectAt: 0.0,
    ])
  }

  private func setShowInDock(_ enabled: Bool) -> Bool {
    guard dockVisibilityController.setEnabled(enabled) else {
      AppLog.write("Dock visibility change failed")
      return false
    }

    AppLog.write(
      enabled ? "Dock icon enabled" : "Dock icon disabled"
    )
    if enabled, settingsWindowController.window?.isVisible == true {
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  private func buildMainMenu() {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)

    let appMenu = NSMenu()
    appMenu.addItem(
      NSMenuItem(
        title: "Quit \(AppConfiguration.appName)",
        action: #selector(menuQuit),
        keyEquivalent: "q"
      )
    )
    appMenuItem.submenu = appMenu
    NSApp.mainMenu = mainMenu
  }

  private func buildMenuBar() {
    statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.squareLength
    )
    if let image = NSImage(
      systemSymbolName: "arrow.triangle.2.circlepath",
      accessibilityDescription: AppConfiguration.appName
    ) {
      image.isTemplate = true
      statusItem.button?.image = image
    } else {
      statusItem.button?.title = "HS"
    }
    statusItem.button?.toolTip = AppConfiguration.appName

    let menu = NSMenu()
    reconnectMenuItem = NSMenuItem(
      title: "Reconnect",
      action: #selector(menuReconnect),
      keyEquivalent: ""
    )
    menu.addItem(reconnectMenuItem)
    menu.addItem(
      NSMenuItem(
        title: "Open Window",
        action: #selector(menuOpenWindow),
        keyEquivalent: ""
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit",
        action: #selector(menuQuit),
        keyEquivalent: "q"
      )
    )
    statusItem.menu = menu
  }

  private func configureDefaultAutoLaunch() {
    let result = autoLaunchController.configureDefaultIfNeeded()
    settingsWindowController.refresh()
    switch result {
    case .success:
      break
    case .failure:
      settingsWindowController.setStatus(
        "Automatic opening couldn't be turned on. You can try again below.",
        isError: true
      )
    }
  }

  private func registerStoredHotKey() {
    let shortcut = storedShortcut(in: UserDefaults.standard)
    persistShortcut(shortcut)
    let status = hotKeyManager.register(
      keyCode: shortcut.keyCode,
      modifiers: shortcut.modifiers
    )
    if status != noErr {
      settingsWindowController.setStatus(
        "That shortcut is already in use. Choose another one.",
        isError: true
      )
    }
  }

  private func changeShortcut(
    keyCode: UInt32,
    modifiers: UInt32,
    display: String
  ) -> Bool {
    let defaults = UserDefaults.standard
    let previousShortcut = storedShortcut(in: defaults)

    guard shortcutValidationMessage(
      keyCode: keyCode,
      modifiers: modifiers
    ) == nil else {
      return false
    }

    let status = hotKeyManager.register(
      keyCode: keyCode,
      modifiers: modifiers
    )
    guard status == noErr else {
      hotKeyManager.register(
        keyCode: previousShortcut.keyCode,
        modifiers: previousShortcut.modifiers
      )
      AppLog.write("Shortcut registration failed with status \(status)")
      return false
    }

    persistShortcut(
      StoredShortcut(
        keyCode: keyCode,
        modifiers: modifiers,
        display: display
      )
    )
    AppLog.write("Global shortcut changed")
    return true
  }

  private func persistShortcut(_ shortcut: StoredShortcut) {
    let defaults = UserDefaults.standard
    defaults.set(Int(shortcut.keyCode), forKey: DefaultsKey.keyCode)
    defaults.set(Int(shortcut.modifiers), forKey: DefaultsKey.modifiers)
    defaults.set(shortcut.display, forKey: DefaultsKey.hotkeyDisplay)
  }

  private func observeHearthstoneTermination() {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self,
        let application = notification.userInfo?[
          NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication,
        application.bundleIdentifier == NativeHearthstoneIdentity.bundleIdentifier
      else {
        return
      }

      if shouldQuitWhenHearthstoneCloses(
        launchedForHearthstone: self.launchedForHearthstone,
        userOpenedWindow: self.userOpenedWindow
      ) {
        AppLog.write("Hearthstone closed; quitting automatic session")
        NSApp.terminate(nil)
      }
    }
  }

  private func showWindow() {
    userOpenedWindow = true
    settingsWindowController.showWindow(nil)
    settingsWindowController.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    settingsWindowController.refresh()
  }

  private func cooldownRemaining() -> TimeInterval {
    let lastReconnectAt = UserDefaults.standard.double(
      forKey: DefaultsKey.lastReconnectAt
    )
    return HSReconnect.cooldownRemaining(
      lastReconnectAt: lastReconnectAt,
      now: Date().timeIntervalSince1970
    )
  }

  private func updateReconnectAvailability() {
    let enabled = !reconnectService.isRunning && cooldownRemaining() <= 0
    reconnectMenuItem?.isEnabled = enabled
    settingsWindowController?.setReconnectEnabled(enabled)
  }

  private func runReconnect() {
    guard !reconnectService.isRunning else {
      settingsWindowController.setStatus(
        "Reconnect is already in progress.",
        isError: true
      )
      return
    }

    let remaining = cooldownRemaining()
    guard remaining <= 0 else {
      settingsWindowController.setStatus(
        "Please wait \(Int(ceil(remaining))) seconds and try again.",
        isError: true
      )
      return
    }

    settingsWindowController.setStatus("Reconnecting…")
    updateReconnectAvailability()
    AppLog.write("Reconnect requested")

    reconnectService.reconnect { result in
      switch result {
      case .success(let output):
        UserDefaults.standard.set(
          helperNetworkTouchTimestamp(output) ?? Date().timeIntervalSince1970,
          forKey: DefaultsKey.lastReconnectAt
        )
        AppLog.write("Reconnect completed: \(output)")
        self.settingsWindowController.setStatus(
          "Reconnect complete."
        )

      case .failure(let error):
        let technicalMessage = "\(error)"
        if helperTouchedNetwork(technicalMessage) {
          UserDefaults.standard.set(
            helperNetworkTouchTimestamp(technicalMessage) ?? Date().timeIntervalSince1970,
            forKey: DefaultsKey.lastReconnectAt
          )
        }
        AppLog.write("Reconnect failed: \(technicalMessage)")
        self.settingsWindowController.setStatus(
          friendlyReconnectFailure(for: technicalMessage),
          isError: true
        )
      }
      self.updateReconnectAvailability()
    }
  }

  @objc private func menuReconnect() {
    runReconnect()
  }

  @objc private func menuOpenWindow() {
    showWindow()
  }

  @objc private func menuQuit() {
    NSApp.terminate(nil)
  }
}

func cooldownRemaining(
  lastReconnectAt: TimeInterval,
  now: TimeInterval
) -> TimeInterval {
  guard lastReconnectAt.isFinite, now.isFinite, lastReconnectAt > 0 else {
    return 0
  }
  let elapsed = now - lastReconnectAt
  if elapsed < 0 {
    return -elapsed <= AppConfiguration.cooldownSeconds
      ? AppConfiguration.cooldownSeconds
      : 0
  }
  return max(0, AppConfiguration.cooldownSeconds - elapsed)
}
