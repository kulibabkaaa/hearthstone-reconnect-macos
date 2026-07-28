import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let launchedForHearthstone: Bool
  private let hotKeyManager = GlobalHotKeyManager()
  private let autoLaunchController = AutoLaunchController()
  private let dockVisibilityController =
    DockVisibilityController()
  private let dockChangeCoordinator =
    DockVisibilityChangeCoordinator()
  private let systemExtensionController =
    SystemExtensionController()
  private let proxyController = TransparentProxyController()
  private lazy var appUninstaller = AppUninstaller(
    autoLaunchController: autoLaunchController,
    proxyController: proxyController,
    systemExtensionController: systemExtensionController
  )

  private var statusItem: NSStatusItem!
  private var reconnectMenuItem: NSMenuItem!
  private var windowController: SettingsWindowController!
  private var cooldownTimer: Timer?
  private var isRecordingShortcut = false
  private var isReconnectRunning = false
  private var isProxyReady = false
  private var isPreparingProxy = false
  private var userOpenedWindow = false
  private var isUninstalling = false
  private var isUninstallCleanupStarted = false
  private var restoreAutoLaunchAfterFailedUninstall = false

  init(launchedForHearthstone: Bool) {
    self.launchedForHearthstone = launchedForHearthstone
    super.init()
  }

  func applicationDidFinishLaunching(
    _ notification: Notification
  ) {
    registerDefaults()
    _ = dockVisibilityController.applyStoredPreference()
    autoLaunchController.synchronizeStoredState()
    buildMainMenu()
    buildMenuBar()
    buildWindow()
    registerStoredHotKey()
    observeHearthstoneTermination()
    prepareProxy()

    if !launchedForHearthstone {
      showWindow()
      _ = autoLaunchController.configureDefaultIfNeeded()
      windowController.refresh()
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

  private func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      DefaultsKey.keyCode:
        Int(AppConfiguration.defaultShortcutKeyCode),
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

  private func buildWindow() {
    windowController = SettingsWindowController(
      onReconnect: { [weak self] in
        self?.runReconnect()
      },
      onShortcutChanged: {
        [weak self] keyCode, modifiers, display in
        self?.changeShortcut(
          keyCode: keyCode,
          modifiers: modifiers,
          display: display
        ) ?? false
      },
      onShortcutRecordingChanged: { [weak self] recording in
        self?.setShortcutRecordingActive(recording)
      },
      onOpenWithHearthstoneChanged: { [weak self] enabled in
        self?.autoLaunchController.setEnabled(enabled)
          ?? .failure(AutoLaunchError.unavailable)
      },
      onShowInDockChanged: {
        [weak self] enabled, completion in
        guard let self else {
          completion(false)
          return
        }
        self.dockChangeCoordinator.submit(enabled) {
          [weak self] finalChoice in
          completion(
            self?.dockVisibilityController.setEnabled(
              finalChoice
            ) ?? false
          )
        }
      },
      onUninstall: { [weak self] in
        self?.confirmUninstall()
      }
    )

    hotKeyManager.onHotKey = { [weak self] in
      guard let self, !self.isRecordingShortcut else { return }
      self.runReconnect()
    }
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

  private func prepareProxy() {
    isProxyReady = false
    windowController.setStatus(
      "Getting ready…"
    )
    systemExtensionController.onApprovalRequired = {
      [weak self] in
      self?.windowController.setStatus(
        "Allow HS Reconnect in System Settings, then return here."
      )
    }
    systemExtensionController.onDeactivationApprovalRequired = {
      [weak self] in
      self?.windowController.setStatus(
        "Approve removing HS Reconnect in System Settings, then return here."
      )
    }
    systemExtensionController.activate { [weak self] result in
      guard let self else { return }
      guard !self.isUninstalling else { return }
      switch result {
      case .failure:
        self.windowController.setStatus(
          self.activationFailureMessage(),
          isError: true
        )
      case .success(.requiresReboot):
        self.windowController.setStatus(
          "Restart your Mac once, then open HS Reconnect again."
        )
      case .success(.activated):
        self.isPreparingProxy = true
        self.proxyController.prepare { [weak self] prepareResult in
          guard let self else { return }
          self.isPreparingProxy = false
          if self.isUninstalling {
            self.beginUninstallCleanup()
            return
          }
          switch prepareResult {
          case .success:
            self.isProxyReady = true
            self.windowController.setStatus(
              "Ready. Start a Battlegrounds game."
            )
          case .failure:
            self.windowController.setStatus(
              "HS Reconnect couldn't start. Please try reopening the app.",
              isError: true
            )
          }
          self.updateReconnectAvailability()
        }
      }
    }
  }

  private func activationFailureMessage() -> String {
    if !Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
      return
        "Move HS Reconnect to Applications, then open it again."
    }
    return
      "HS Reconnect couldn't be enabled. Please try reopening the app."
  }

  private func runReconnect() {
    guard isProxyReady else {
      windowController.setStatus(
        "The local proxy is still getting ready.",
        isError: true
      )
      return
    }
    guard !isReconnectRunning else {
      windowController.setStatus(
        "Reconnect is already in progress.",
        isError: true
      )
      return
    }

    let remaining = ReconnectCooldown.remaining(
      lastReconnectAt: UserDefaults.standard.double(
        forKey: DefaultsKey.lastReconnectAt
      ),
      now: Date().timeIntervalSince1970
    )
    guard remaining <= 0 else {
      windowController.setStatus(
        "Please wait \(Int(ceil(remaining))) seconds and try again.",
        isError: true
      )
      return
    }

    isReconnectRunning = true
    windowController.setStatus("Reconnecting…")
    updateReconnectAvailability()

    let target: ReconnectTarget
    do {
      target = try GameEndpointResolver().reconnectTarget()
    } catch {
      isReconnectRunning = false
      windowController.setStatus(
        "Start a Battlegrounds game and try again.",
        isError: true
      )
      updateReconnectAvailability()
      return
    }

    proxyController.reconnect(target: target) { [weak self] result in
      guard let self else { return }
      guard !self.isUninstalling else { return }
      self.isReconnectRunning = false
      switch result {
      case .failure:
        self.windowController.setStatus(
          "Reconnect couldn't be completed. Please try again.",
          isError: true
        )
      case .success(let response):
        if response.didCloseFlow {
          UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: DefaultsKey.lastReconnectAt
          )
          self.windowController.setStatus(
            "Reconnect triggered."
          )
        } else {
          self.windowController.setStatus(
            "Start a Battlegrounds game and try again.",
            isError: true
          )
        }
      }
      self.updateReconnectAvailability()
    }
  }

  private func updateReconnectAvailability() {
    let remaining = ReconnectCooldown.remaining(
      lastReconnectAt: UserDefaults.standard.double(
        forKey: DefaultsKey.lastReconnectAt
      ),
      now: Date().timeIntervalSince1970
    )
    let enabled =
      isProxyReady && !isReconnectRunning && remaining <= 0
    reconnectMenuItem?.isEnabled = enabled
    windowController?.setReconnectEnabled(enabled)
  }

  private func registerStoredHotKey() {
    let shortcut = storedShortcut(in: .standard)
    persistShortcut(shortcut)
    if hotKeyManager.register(
      keyCode: shortcut.keyCode,
      modifiers: shortcut.modifiers
    ) != noErr {
      windowController?.setStatus(
        "That shortcut is already in use. Choose another one.",
        isError: true
      )
    }
  }

  private func setShortcutRecordingActive(_ recording: Bool) {
    if recording {
      isRecordingShortcut = true
      hotKeyManager.unregister()
    } else {
      registerStoredHotKey()
      isRecordingShortcut = false
    }
  }

  private func changeShortcut(
    keyCode: UInt32,
    modifiers: UInt32,
    display: String
  ) -> Bool {
    guard
      shortcutValidationMessage(
        keyCode: keyCode,
        modifiers: modifiers
      ) == nil
    else {
      return false
    }

    let previous = storedShortcut(in: .standard)
    let status = hotKeyManager.register(
      keyCode: keyCode,
      modifiers: modifiers
    )
    guard status == noErr else {
      _ = hotKeyManager.register(
        keyCode: previous.keyCode,
        modifiers: previous.modifiers
      )
      return false
    }

    persistShortcut(
      StoredShortcut(
        keyCode: keyCode,
        modifiers: modifiers,
        display: display
      )
    )
    return true
  }

  private func persistShortcut(_ shortcut: StoredShortcut) {
    UserDefaults.standard.set(
      Int(shortcut.keyCode),
      forKey: DefaultsKey.keyCode
    )
    UserDefaults.standard.set(
      Int(shortcut.modifiers),
      forKey: DefaultsKey.modifiers
    )
    UserDefaults.standard.set(
      shortcut.display,
      forKey: DefaultsKey.hotkeyDisplay
    )
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
        application.bundleIdentifier
          == ProxyConstants.hearthstoneSigningIdentifier,
        self.launchedForHearthstone,
        !self.userOpenedWindow
      else {
        return
      }
      NSApp.terminate(nil)
    }
  }

  private func showWindow() {
    userOpenedWindow = true
    windowController.showWindow(nil)
    windowController.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    windowController.refresh()
  }

  private func confirmUninstall() {
    guard !isUninstalling else { return }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Uninstall HS Reconnect?"
    alert.informativeText =
      "This removes HS Reconnect, its network extension, settings, and Desktop shortcut."
    alert.addButton(withTitle: "Uninstall")
    alert.addButton(withTitle: "Cancel")
    alert.buttons.first?.hasDestructiveAction = true

    guard alert.runModal() == .alertFirstButtonReturn else {
      return
    }

    isUninstalling = true
    isUninstallCleanupStarted = false
    restoreAutoLaunchAfterFailedUninstall =
      UserDefaults.standard.bool(
        forKey: DefaultsKey.openWithHearthstone
      )
    isProxyReady = false
    hotKeyManager.unregister()
    windowController.setUninstalling(true)
    windowController.setStatus("Uninstalling HS Reconnect…")
    updateReconnectAvailability()

    if !isPreparingProxy {
      beginUninstallCleanup()
    }
  }

  private func beginUninstallCleanup() {
    guard isUninstalling, !isUninstallCleanupStarted else {
      return
    }
    isUninstallCleanupStarted = true

    appUninstaller.uninstall { [weak self] result in
      guard let self else { return }
      switch result {
      case .success:
        NSApp.terminate(nil)
      case .failure(let error):
        self.isUninstalling = false
        self.isUninstallCleanupStarted = false
        self.isReconnectRunning = false
        if self.restoreAutoLaunchAfterFailedUninstall {
          _ = self.autoLaunchController.setEnabled(true)
        }
        self.restoreAutoLaunchAfterFailedUninstall = false
        self.registerStoredHotKey()
        self.windowController.setUninstalling(false)
        self.windowController.setStatus(
          self.uninstallFailureMessage(error),
          isError: true
        )
        self.updateReconnectAvailability()
        self.prepareProxy()
      }
    }
  }

  private func uninstallFailureMessage(_ error: Error) -> String {
    if let error = error as? AppUninstallerError,
      case .notInstalledInApplications = error
    {
      return
        "Open the installed copy from Applications, then try again."
    }
    return "HS Reconnect couldn't be uninstalled. Please try again."
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
