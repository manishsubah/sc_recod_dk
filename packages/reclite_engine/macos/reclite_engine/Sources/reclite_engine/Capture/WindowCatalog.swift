import AppKit
import ScreenCaptureKit

/// Normal app windows that can be recorded on their own (RecLite's excluded).
enum WindowCatalog {
  private static let minimumSize: CGFloat = 64

  static func windows() async throws -> [EngineWindow] {
    let content = try await SCShareableContent.excludingDesktopWindows(
      true, onScreenWindowsOnly: true)
    let pid = ProcessInfo.processInfo.processIdentifier
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    return content.windows
      .filter { window in
        window.windowLayer == 0
          && window.owningApplication?.processID != pid
          && !(window.title ?? "").isEmpty
          && window.frame.width >= minimumSize && window.frame.height >= minimumSize
      }
      .map { window in
        EngineWindow(
          id: Int64(window.windowID),
          title: window.title ?? "",
          appName: window.owningApplication?.applicationName ?? "",
          width: Int64(window.frame.width * scale),
          height: Int64(window.frame.height * scale))
      }
  }
}
