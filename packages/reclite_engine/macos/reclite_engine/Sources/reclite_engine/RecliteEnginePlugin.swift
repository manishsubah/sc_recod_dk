import AppKit
import FlutterMacOS
import Foundation

public final class RecliteEnginePlugin: NSObject, FlutterPlugin, EngineHostApi {
  private let engine: RecordingEngine
  private let shortcuts: GlobalShortcuts
  private let windowController: WindowController
  private let tray: TrayIcon

  @MainActor
  private init(messenger: FlutterBinaryMessenger) {
    let events = EngineEventsApi(binaryMessenger: messenger)
    engine = RecordingEngine(events: events)
    shortcuts = GlobalShortcuts { index in
      Task { try? await events.onShortcut(index: Int64(index)) }
    }
    let windowController = WindowController()
    self.windowController = windowController
    tray = TrayIcon { command in
      if command == .showWindow { windowController.bringToFront() }
      Task { try? await events.onTrayCommand(command: command) }
    }
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

  func listWindows() async throws -> [EngineWindow] {
    guard ScreenCapturePermission.isGranted else { throw EngineErrors.permissionDenied }
    do {
      return try await WindowCatalog.windows()
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

  func setGlobalShortcuts(shortcuts list: [EngineShortcut]) throws -> [Int64] {
    MainActor.assumeIsolated { shortcuts.set(list) }
  }

  func setMiniWindow(mini: Bool) throws {
    MainActor.assumeIsolated { windowController.setMini(mini) }
  }

  func startWindowDrag() throws {
    MainActor.assumeIsolated { windowController.startDrag() }
  }

  func setTrayState(state: EngineTrayState) throws {
    MainActor.assumeIsolated { tray.setState(state) }
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

  func openPath(path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
      throw EngineErrors.make("invalid_path", "Path does not exist: \(path)")
    }
    guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
      throw EngineErrors.make("open_failed", "No app could open \(path)")
    }
  }

  func openUrl(url: String) throws {
    // Only web and mail links: never let a string from Dart start a program.
    guard let link = URL(string: url), ["https", "http", "mailto"].contains(link.scheme)
    else {
      throw EngineErrors.make("invalid_url", "Only web and mail links can be opened.")
    }
    guard NSWorkspace.shared.open(link) else {
      throw EngineErrors.make("open_failed", "No app could open \(url)")
    }
  }

  func moveToTrash(path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
      throw EngineErrors.make("invalid_path", "Path does not exist: \(path)")
    }
    do {
      try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    } catch {
      throw EngineErrors.make("trash_failed", "Could not move to the Trash: \(path)")
    }
  }
}
