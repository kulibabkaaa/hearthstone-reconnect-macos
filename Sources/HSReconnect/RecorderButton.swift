import AppKit
import Carbon

final class RecorderButton: NSButton {
  var onRecord: ((UInt32, UInt32, String) -> Bool)?
  var onValidationMessage: ((String) -> Void)?

  private var isRecordingShortcut = false
  private var previousTitle = ""

  override var acceptsFirstResponder: Bool { true }

  func beginRecording() {
    guard !isRecordingShortcut else { return }
    LegacyApplicationMigration.terminateRunningApplications()
    isRecordingShortcut = true
    previousTitle = title
    title = "Press shortcut…"
    window?.makeFirstResponder(self)
  }

  override func mouseDown(with event: NSEvent) {
    beginRecording()
  }

  override func keyDown(with event: NSEvent) {
    guard isRecordingShortcut else {
      super.keyDown(with: event)
      return
    }

    if event.keyCode == UInt16(kVK_Escape) {
      isRecordingShortcut = false
      title = previousTitle
      onValidationMessage?("Shortcut change cancelled.")
      return
    }

    let relevantFlags = event.modifierFlags.intersection([
      .command,
      .shift,
      .option,
      .control,
    ])
    let modifiers = carbonModifiers(from: relevantFlags)
    guard modifiers != 0 else {
      onValidationMessage?("Add Command, Shift, Option, or Control.")
      return
    }

    let modifierText = displayModifiers(from: relevantFlags)
    let keyText = keyName(for: event)
    let display = "\(modifierText)+\(keyText)"
    isRecordingShortcut = false

    if onRecord?(UInt32(event.keyCode), modifiers, display) == true {
      title = display
      previousTitle = display
    } else {
      title = previousTitle
    }
  }
}
