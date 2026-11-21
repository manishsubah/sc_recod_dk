import Carbon.HIToolbox
import Foundation

/// System-wide hotkeys via Carbon's RegisterEventHotKey: they work while another app
/// is active and need no Accessibility permission.
@MainActor
final class GlobalShortcuts {
  nonisolated private static let signature: OSType = 0x524C_5354  // "RLST"

  private static let keyCodes: [String: Int] = [
    "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E,
    "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J,
    "K": kVK_ANSI_K, "L": kVK_ANSI_L, "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O,
    "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
    "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X, "Y": kVK_ANSI_Y,
    "Z": kVK_ANSI_Z,
    "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
    "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    "F1": kVK_F1, "F2": kVK_F2, "F3": kVK_F3, "F4": kVK_F4, "F5": kVK_F5, "F6": kVK_F6,
    "F7": kVK_F7, "F8": kVK_F8, "F9": kVK_F9, "F10": kVK_F10, "F11": kVK_F11, "F12": kVK_F12,
  ]

  private let onPressed: @MainActor (Int) -> Void
  private var hotKeys: [EventHotKeyRef] = []
  private var handler: EventHandlerRef?

  /// [onPressed] gets the shortcut's index in the last `set` call.
  init(onPressed: @escaping @MainActor (Int) -> Void) {
    self.onPressed = onPressed
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let event, let context else { return OSStatus(eventNotHandledErr) }
        var hotKey = EventHotKeyID()
        let status = GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
          nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
        guard status == noErr, hotKey.signature == GlobalShortcuts.signature else {
          return OSStatus(eventNotHandledErr)
        }
        let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { shortcuts.onPressed(Int(hotKey.id) - 1) }
        return noErr
      },
      1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
  }

  /// Replaces all shortcuts; returns the indexes that could not be registered.
  func set(_ shortcuts: [EngineShortcut]) -> [Int64] {
    hotKeys.forEach { UnregisterEventHotKey($0) }
    hotKeys.removeAll()
    var failed: [Int64] = []
    for (index, shortcut) in shortcuts.enumerated() {
      guard let code = Self.keyCodes[shortcut.key] else {
        failed.append(Int64(index))
        continue
      }
      var modifiers = 0
      if shortcut.control { modifiers |= controlKey }
      if shortcut.alt { modifiers |= optionKey }
      if shortcut.shift { modifiers |= shiftKey }
      if shortcut.meta { modifiers |= cmdKey }
      var ref: EventHotKeyRef?
      let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
      let status = RegisterEventHotKey(
        UInt32(code), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
      if status == noErr, let ref {
        hotKeys.append(ref)
      } else {
        failed.append(Int64(index))
      }
    }
    return failed
  }
}
