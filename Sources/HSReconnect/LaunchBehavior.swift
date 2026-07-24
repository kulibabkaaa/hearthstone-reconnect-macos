func shouldQuitWhenHearthstoneCloses(
  launchedForHearthstone: Bool,
  userOpenedWindow: Bool
) -> Bool {
  launchedForHearthstone && !userOpenedWindow
}
