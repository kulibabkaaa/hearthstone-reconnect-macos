import AppKit
import Carbon

func fourCharacterCode(_ value: String) -> FourCharCode {
  var result: FourCharCode = 0
  for scalar in value.unicodeScalars.prefix(4) {
    result = (result << 8) + FourCharCode(scalar.value)
  }
  return result
}

func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
  var result: UInt32 = 0
  if flags.contains(.command) { result |= UInt32(cmdKey) }
  if flags.contains(.shift) { result |= UInt32(shiftKey) }
  if flags.contains(.option) { result |= UInt32(optionKey) }
  if flags.contains(.control) { result |= UInt32(controlKey) }
  return result
}

func displayModifiers(from flags: NSEvent.ModifierFlags) -> String {
  var parts: [String] = []
  if flags.contains(.control) { parts.append("Ctrl") }
  if flags.contains(.option) { parts.append("Option") }
  if flags.contains(.shift) { parts.append("Shift") }
  if flags.contains(.command) { parts.append("Cmd") }
  return parts.joined(separator: "+")
}

func keyName(for event: NSEvent) -> String {
  if event.keyCode == UInt16(kVK_Space) {
    return "Space"
  }
  if let value = event.charactersIgnoringModifiers, !value.isEmpty {
    return value.uppercased()
  }
  return "Key \(event.keyCode)"
}

final class GlobalHotKeyManager {
  private var hotKeyReference: EventHotKeyRef?
  private var handlerReference: EventHandlerRef?
  var onHotKey: (() -> Void)?

  init() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, context in
        guard let context else { return noErr }
        let manager = Unmanaged<GlobalHotKeyManager>
          .fromOpaque(context)
          .takeUnretainedValue()
        manager.onHotKey?()
        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &handlerReference
    )
  }

  deinit {
    unregister()
    if let handlerReference {
      RemoveEventHandler(handlerReference)
    }
  }

  @discardableResult
  func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
    unregister()
    let identifier = EventHotKeyID(
      signature: fourCharacterCode("HSRC"),
      id: 1
    )
    return RegisterEventHotKey(
      keyCode,
      modifiers,
      identifier,
      GetApplicationEventTarget(),
      0,
      &hotKeyReference
    )
  }

  func unregister() {
    if let hotKeyReference {
      UnregisterEventHotKey(hotKeyReference)
      self.hotKeyReference = nil
    }
  }
}
