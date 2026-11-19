import AppKit

/// Full-screen overlay where the user drags out the area to record.
@MainActor
final class AreaSelector {
  static let minimumSize: CGFloat = 64

  private var window: OverlayWindow?
  private var continuation: CheckedContinuation<CGRect?, Never>?

  /// Returns the rect in points with origin at the screen's top-left, or nil if cancelled.
  func select(on screen: NSScreen) async -> CGRect? {
    finish(with: nil)
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      let window = OverlayWindow(screen: screen) { [weak self] rect in
        self?.finish(with: rect)
      }
      self.window = window
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
    }
  }

  private func finish(with rect: CGRect?) {
    window?.orderOut(nil)
    window = nil
    continuation?.resume(returning: rect)
    continuation = nil
  }
}

private final class OverlayWindow: NSWindow {
  init(screen: NSScreen, onDone: @escaping (CGRect?) -> Void) {
    super.init(
      contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    setFrame(screen.frame, display: false)
    level = .screenSaver
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = false
    isReleasedWhenClosed = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    contentView = SelectionView(onDone: onDone)
  }

  override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
  private let onDone: (CGRect?) -> Void
  private var start: NSPoint?
  private var current: NSPoint?

  init(onDone: @escaping (CGRect?) -> Void) {
    self.onDone = onDone
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { true }

  override func viewDidMoveToWindow() {
    window?.makeFirstResponder(self)
    window?.invalidateCursorRects(for: self)
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {  // Esc
      onDone(nil)
    } else {
      super.keyDown(with: event)
    }
  }

  override func mouseDown(with event: NSEvent) {
    start = convert(event.locationInWindow, from: nil)
    current = start
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    current = convert(event.locationInWindow, from: nil)
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    current = convert(event.locationInWindow, from: nil)
    guard let rect = selection,
      rect.width >= AreaSelector.minimumSize, rect.height >= AreaSelector.minimumSize
    else {
      start = nil
      current = nil
      needsDisplay = true
      return
    }
    // View coordinates start bottom-left; ScreenCaptureKit wants top-left.
    onDone(
      CGRect(
        x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height
      ).integral)
  }

  private var selection: CGRect? {
    guard let start, let current else { return nil }
    return CGRect(
      x: min(start.x, current.x), y: min(start.y, current.y),
      width: abs(current.x - start.x), height: abs(current.y - start.y))
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.35).setFill()
    bounds.fill()

    guard let rect = selection else {
      drawLabel(
        "Drag to select the area to record  ·  Esc to cancel",
        centeredAt: NSPoint(x: bounds.midX, y: bounds.maxY - 80))
      return
    }

    NSColor.clear.setFill()
    rect.fill(using: .copy)
    NSColor.white.setStroke()
    let border = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
    border.lineWidth = 2
    border.stroke()

    let size = "\(Int(rect.width)) × \(Int(rect.height))"
    drawLabel(size, centeredAt: NSPoint(x: rect.midX, y: max(rect.minY - 24, 16)))
  }

  private func drawLabel(_ text: String, centeredAt point: NSPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
      .foregroundColor: NSColor.white,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let size = string.size()
    let padded = NSRect(
      x: point.x - size.width / 2 - 10, y: point.y - size.height / 2 - 5,
      width: size.width + 20, height: size.height + 10)
    NSColor.black.withAlphaComponent(0.7).setFill()
    NSBezierPath(roundedRect: padded, xRadius: 8, yRadius: 8).fill()
    string.draw(at: NSPoint(x: padded.minX + 10, y: padded.minY + 5))
  }
}
