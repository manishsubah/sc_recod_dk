import AppKit
import CoreGraphics

enum ScreenCapturePermission {
  /// macOS may keep reporting `false` until the app is relaunched after the user grants access.
  static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

  static func request() -> Bool { CGRequestScreenCaptureAccess() }

  static func openSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    else { return }
    NSWorkspace.shared.open(url)
  }
}
