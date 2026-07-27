import Foundation

func friendlyReconnectFailure(for technicalMessage: String) -> String {
  let message = technicalMessage.lowercased()

  if message.contains("not running") || message.contains("multiple native hearthstone") {
    return "Open Hearthstone and try again."
  }

  if message.contains("no active native hearthstone battlegrounds")
    || message.contains("gamenetlogger endpoint")
    || message.contains("no established public ipv4 tcp connections")
  {
    return "Start a Battlegrounds game and try again."
  }

  if message.contains("hearthstone signature") {
    return "Hearthstone couldn't be verified. Repair or reinstall Hearthstone, then try again."
  }

  if message.contains("sudo") || message.contains("helper") || message.contains("permission denied")
    || message.contains("not permitted")
  {
    return "HS Reconnect needs to be reinstalled. Download and run the latest installer."
  }

  if message.contains("already running") || message.contains("lock is busy") {
    return "Reconnect is already in progress."
  }

  return "Reconnect couldn't be completed. Please try again."
}
