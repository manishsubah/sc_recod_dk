import AppKit
import ScreenCaptureKit

enum DisplayCatalog {
  static func shareableContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
  }

  static func displays() async throws -> [EngineDisplay] {
    let content = try await shareableContent()
    let mainID = CGMainDisplayID()
    return content.displays
      .map { display in
        let pixels = pixelSize(of: display)
        return EngineDisplay(
          id: Int64(display.displayID),
          name: screen(for: display.displayID)?.localizedName ?? "Display \(display.displayID)",
          width: Int64(pixels.width),
          height: Int64(pixels.height),
          isMain: display.displayID == mainID
        )
      }
      .sorted { $0.isMain && !$1.isMain }
  }

  /// SCDisplay reports points; HiDPI screens have 2x (or more) pixels.
  static func pixelSize(of display: SCDisplay) -> (width: Int, height: Int) {
    if let mode = CGDisplayCopyDisplayMode(display.displayID) {
      return (mode.pixelWidth, mode.pixelHeight)
    }
    let scale = screen(for: display.displayID)?.backingScaleFactor ?? 1
    return (Int(Double(display.width) * scale), Int(Double(display.height) * scale))
  }

  static func screen(for id: CGDirectDisplayID) -> NSScreen? {
    NSScreen.screens.first {
      ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        == id
    }
  }
}
