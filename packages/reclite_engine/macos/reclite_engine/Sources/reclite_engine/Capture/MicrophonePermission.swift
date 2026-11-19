import AVFoundation
import AppKit

enum MicrophonePermission {
  static var isGranted: Bool {
    AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  }

  /// Prompts only while undecided; afterwards returns the stored answer.
  static func request() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
    default: return false
    }
  }

  static func openSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    else { return }
    NSWorkspace.shared.open(url)
  }
}
