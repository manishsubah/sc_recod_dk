import AppKit

/// Red outline around the recorded area. Never appears in the video, because
/// RecLite's own windows are excluded from capture.
@MainActor
final class AreaHighlight {
  private static let thickness: CGFloat = 3

  private var window: NSWindow?

  /// `area` is in points with origin at the screen's top-left.
  func show(_ area: CGRect, on screen: NSScreen) {
    hide()
    let frame = CGRect(
      x: screen.frame.minX + area.minX,
      y: screen.frame.maxY - area.maxY,
      width: area.width,
      height: area.height
    ).insetBy(dx: -Self.thickness, dy: -Self.thickness)

    let window = NSWindow(
      contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = .statusBar
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

    let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
    view.wantsLayer = true
    view.layer?.borderWidth = Self.thickness
    view.layer?.borderColor = NSColor.systemRed.cgColor
    window.contentView = view
    window.orderFrontRegardless()
    self.window = window
  }

  func hide() {
    window?.orderOut(nil)
    window = nil
  }
}
