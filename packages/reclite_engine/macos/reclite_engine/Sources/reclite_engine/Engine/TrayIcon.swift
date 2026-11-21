import AppKit

/// Menu-bar item: a record symbol (red while recording, orange while paused) with
/// Start/Stop, Pause/Resume and Show RecLite.
@MainActor
final class TrayIcon: NSObject {
  private let onCommand: @MainActor (EngineTrayCommand) -> Void
  private var item: NSStatusItem?
  private var state: EngineTrayState = .idle

  init(onCommand: @escaping @MainActor (EngineTrayCommand) -> Void) {
    self.onCommand = onCommand
  }

  func setState(_ state: EngineTrayState) {
    self.state = state
    let item = self.item ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    self.item = item

    let (symbol, tint): (String, NSColor?) =
      switch state {
      case .recording: ("record.circle.fill", .systemRed)
      case .paused: ("pause.circle.fill", .systemOrange)
      case .idle: ("record.circle", nil)
      }
    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "RecLite")
    image?.isTemplate = tint == nil
    item.button?.image = image
    item.button?.contentTintColor = tint
    item.button?.toolTip =
      switch state {
      case .recording: "RecLite – recording"
      case .paused: "RecLite – paused"
      case .idle: "RecLite"
      }
    item.menu = makeMenu()
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    let busy = state != .idle
    menu.addItem(
      menuItem(busy ? "Stop Recording" : "Start Recording", #selector(startStop)))
    if busy {
      menu.addItem(menuItem(state == .paused ? "Resume" : "Pause", #selector(pauseResume)))
    }
    menu.addItem(.separator())
    menu.addItem(menuItem("Show RecLite", #selector(showWindow)))
    return menu
  }

  private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func startStop() { onCommand(.startStop) }
  @objc private func pauseResume() { onCommand(.pauseResume) }
  @objc private func showWindow() { onCommand(.showWindow) }
}
