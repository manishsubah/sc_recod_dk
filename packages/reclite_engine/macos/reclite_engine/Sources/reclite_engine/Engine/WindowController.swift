import AppKit
import FlutterMacOS

/// Turns RecLite's main window into a small floating bar and back.
@MainActor
final class WindowController {
  private static let miniSize = NSSize(width: 380, height: 56)
  private static let miniTopGap: CGFloat = 12

  private struct Saved {
    let frame: NSRect
    let minSize: NSSize
    let level: NSWindow.Level
    let styleMask: NSWindow.StyleMask
  }

  private var saved: Saved?

  private var window: NSWindow? {
    NSApp.windows.first { $0.contentViewController is FlutterViewController } ?? NSApp.mainWindow
  }

  func setMini(_ mini: Bool) {
    guard let window else { return }
    if mini {
      guard saved == nil else { return }
      saved = Saved(
        frame: window.frame, minSize: window.contentMinSize, level: window.level,
        styleMask: window.styleMask)
      window.contentMinSize = NSSize(width: 1, height: 1)
      window.styleMask.insert(.fullSizeContentView)
      window.styleMask.remove(.resizable)
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      setStandardButtonsHidden(true, in: window)
      window.level = .floating
      let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
      let frame = NSRect(
        x: visible.midX - Self.miniSize.width / 2,
        y: visible.maxY - Self.miniSize.height - Self.miniTopGap,
        width: Self.miniSize.width, height: Self.miniSize.height)
      window.setFrame(frame, display: true)
      return
    }
    guard let saved else { return }
    self.saved = nil
    window.level = saved.level
    window.styleMask = saved.styleMask
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
    setStandardButtonsHidden(false, in: window)
    window.contentMinSize = saved.minSize
    window.setFrame(saved.frame, display: true)
    bringToFront()
  }

  /// Moves the window with the mouse; works while the button that started it is down.
  func startDrag() {
    guard let window, let event = NSApp.currentEvent else { return }
    window.performDrag(with: event)
  }

  func bringToFront() {
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  private func setStandardButtonsHidden(_ hidden: Bool, in window: NSWindow) {
    for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      window.standardWindowButton(button)?.isHidden = hidden
    }
  }
}
