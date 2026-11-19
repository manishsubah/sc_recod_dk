import AppKit
import FlutterMacOS
import Foundation

public final class RecliteEnginePlugin: NSObject, FlutterPlugin, EngineHostApi {
  private let engine: RecordingEngine

  @MainActor
  private init(messenger: FlutterBinaryMessenger) {
    engine = RecordingEngine(events: EngineEventsApi(binaryMessenger: messenger))
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MainActor.assumeIsolated { RecliteEnginePlugin(messenger: registrar.messenger) }
    EngineHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
  }

  func getCapabilities() throws -> EngineCapabilities {
    CapabilitiesProbe.current()
  }

  func getDiskSpace(path: String) throws -> DiskSpace {
    try DiskSpaceProbe.query(path: path)
  }

  func hasScreenCapturePermission() throws -> Bool {
    ScreenCapturePermission.isGranted
  }

  func requestScreenCapturePermission() throws -> Bool {
    ScreenCapturePermission.request()
  }

  func openScreenCaptureSettings() throws {
    ScreenCapturePermission.openSettings()
  }

  func hasMicrophonePermission() throws -> Bool {
    MicrophonePermission.isGranted
  }

  func requestMicrophonePermission() async throws -> Bool {
    await MicrophonePermission.request()
  }

  func openMicrophoneSettings() throws {
    MicrophonePermission.openSettings()
  }

  func listDisplays() async throws -> [EngineDisplay] {
    guard ScreenCapturePermission.isGranted else { throw EngineErrors.permissionDenied }
    do {
      return try await DisplayCatalog.displays()
    } catch {
      throw EngineErrors.captureFailed(error)
    }
  }

  func startRecording(request: EngineRecordingRequest) async throws -> EngineRecordingSession {
    try await engine.start(request)
  }

  func pauseRecording() throws {
    try MainActor.assumeIsolated { try engine.pause() }
  }

  func resumeRecording() throws {
    try MainActor.assumeIsolated { try engine.resume() }
  }

  func stopRecording() async throws -> EngineRecordingResult {
    try await engine.stop()
  }

  func recoverSessions(outputDirectory: String) async throws -> [EngineRecoveredSession] {
    await engine.recoverSessions(in: outputDirectory)
  }

  func selectArea(displayId: Int64) async throws -> EngineCaptureArea? {
    try await engine.selectArea(displayId: displayId)
  }

  func revealInFileManager(path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      throw EngineErrors.make("invalid_path", "Path does not exist: \(path)")
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
