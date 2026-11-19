import Foundation

enum EngineErrors {
  static func make(_ code: String, _ message: String) -> PigeonError {
    PigeonError(code: code, message: message, details: nil)
  }

  static let permissionDenied = make(
    "permission_denied", "Screen recording permission is not granted.")
  static let alreadyRecording = make("already_recording", "A recording is already running.")
  static let notRecording = make("not_recording", "No recording is running.")
  static let displayNotFound = make("display_not_found", "The selected display is not available.")

  static func captureFailed(_ error: Error) -> PigeonError {
    make("capture_failed", error.localizedDescription)
  }

  static func writerFailed(_ error: Error?) -> PigeonError {
    make("writer_failed", error?.localizedDescription ?? "The video file could not be written.")
  }
}
