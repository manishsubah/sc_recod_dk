import CoreMedia
import Foundation
import ScreenCaptureKit

/// Owns the recording lifecycle. All state lives on the main actor; frames never do.
@MainActor
final class RecordingEngine {
  private final class ActiveSession {
    let capture: CaptureSession
    let directory: URL
    var manifest: SessionManifest
    let sleepGuard: NSObjectProtocol
    var lowSpaceWarned = false
    var ticks = 0

    init(
      capture: CaptureSession, directory: URL, manifest: SessionManifest,
      sleepGuard: NSObjectProtocol
    ) {
      self.capture = capture
      self.directory = directory
      self.manifest = manifest
      self.sleepGuard = sleepGuard
    }
  }

  static let minimumSegmentSeconds: Int64 = 5

  private let events: EngineEventsApi
  private var phase: EngineRecordingPhase = .idle
  private var session: ActiveSession?
  private var ticker: Timer?
  private var levelTicker: Timer?
  private let highlight = AreaHighlight()
  private let areaSelector = AreaSelector()

  init(events: EngineEventsApi) {
    self.events = events
  }

  func selectArea(displayId: Int64) async throws -> EngineCaptureArea? {
    guard phase == .idle else { throw EngineErrors.alreadyRecording }
    guard let screen = DisplayCatalog.screen(for: CGDirectDisplayID(displayId)) else {
      throw EngineErrors.displayNotFound
    }
    guard let rect = await areaSelector.select(on: screen) else { return nil }
    return EngineCaptureArea(
      x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
  }

  func start(_ request: EngineRecordingRequest) async throws -> EngineRecordingSession {
    guard phase == .idle else { throw EngineErrors.alreadyRecording }
    guard ScreenCapturePermission.isGranted else { throw EngineErrors.permissionDenied }
    let audioSources = try Self.audioSources(for: request)

    setPhase(.starting)
    var directory: URL?
    do {
      let content = try await DisplayCatalog.shareableContent()
      guard
        let display = content.displays.first(where: { Int64($0.displayID) == request.displayId })
      else { throw EngineErrors.displayNotFound }

      let pixels = DisplayCatalog.pixelSize(of: display)
      let area = try request.area.map { try Self.validated($0, on: display) }
      let pixelsPerPoint = Double(pixels.width) / Double(display.width)
      let sourcePixels =
        area.map {
          (Int($0.width * pixelsPerPoint), Int($0.height * pixelsPerPoint))
        } ?? pixels
      let size = OutputSize.fit(
        width: sourcePixels.0, height: sourcePixels.1, maxHeight: Int(request.maxHeight))
      let fps = Int(request.framesPerSecond)
      let segmentSeconds = max(request.segmentSeconds, Self.minimumSegmentSeconds)

      let startedAt = Date()
      let sessionDirectory = try SessionNaming.createSessionDirectory(
        in: URL(fileURLWithPath: request.outputDirectory, isDirectory: true), startedAt: startedAt)
      directory = sessionDirectory

      let settings = SegmentedRecorder.Settings(
        segmentDuration: CMTime(value: segmentSeconds, timescale: 1),
        width: size.width, height: size.height, framesPerSecond: fps,
        audioSourceCount: audioSources.count,
        makeURL: { index, date in
          sessionDirectory.appendingPathComponent(
            SessionNaming.segmentFileName(startedAt: index == 1 ? startedAt : date, index: index))
        })
      let capture = try CaptureSession(
        filter: Self.filter(for: display, in: content),
        configuration: Self.configuration(
          width: size.width, height: size.height, fps: fps, sourceRect: area,
          audio: audioSources),
        settings: settings,
        audioSources: audioSources)

      let manifest = SessionManifest(
        sessionId: SessionNaming.stamp(startedAt),
        startedAt: startedAt,
        status: .recording,
        source: .init(
          type: area == nil ? "display" : "area",
          name: DisplayCatalog.screen(for: display.displayID)?.localizedName
            ?? "Display \(display.displayID)",
          area: area.map { [$0.minX, $0.minY, $0.width, $0.height] }),
        audio: .init(
          system: audioSources.contains(.system), microphone: audioSources.contains(.microphone)),
        video: .init(codec: "h264", width: size.width, height: size.height, fps: fps),
        segmentSeconds: Int(segmentSeconds),
        segments: [])
      try manifest.write(to: sessionDirectory)

      capture.onStreamStopped = { [weak self] error in self?.handleStreamStopped(error) }
      capture.onPartFinished = { [weak self] part in self?.record(part) }
      capture.onWriteFailure = { [weak self] error in
        self?.endAfterFailure(
          EngineError(
            code: "writer_failed",
            message:
              "Recording stopped: the video could not be written (\(error.localizedDescription)). "
              + "Finished parts were saved.",
            isFatal: true))
      }
      try await capture.start()

      if let area, let screen = DisplayCatalog.screen(for: display.displayID) {
        highlight.show(area, on: screen)
      }

      session = ActiveSession(
        capture: capture, directory: sessionDirectory, manifest: manifest,
        sleepGuard: ProcessInfo.processInfo.beginActivity(
          options: [.userInitiated, .idleSystemSleepDisabled],
          reason: "RecLite is recording the screen"))
      setPhase(.recording)
      startTicker()
      if !audioSources.isEmpty { startLevelTicker() }
      return EngineRecordingSession(
        sessionDirectory: sessionDirectory.path, width: Int64(size.width),
        height: Int64(size.height))
    } catch {
      if let directory { Self.removeIfUnused(directory) }
      setPhase(.idle)
      throw error is PigeonError ? error : EngineErrors.captureFailed(error)
    }
  }

  func pause() throws {
    guard phase == .recording, let session else { throw EngineErrors.notRecording }
    session.capture.pause()
    setPhase(.paused)
  }

  func resume() throws {
    guard phase == .paused, let session else { throw EngineErrors.notRecording }
    session.capture.resume()
    setPhase(.recording)
  }

  func stop() async throws -> EngineRecordingResult {
    guard phase == .recording || phase == .paused, let session else {
      throw EngineErrors.notRecording
    }
    return try await finish(session, streamAlreadyStopped: false)
  }

  func recoverSessions(in outputDirectory: String) async -> [EngineRecoveredSession] {
    let recovered = await SessionRecovery.recover(
      in: URL(fileURLWithPath: outputDirectory, isDirectory: true), skipping: session?.directory)
    return recovered.map {
      EngineRecoveredSession(
        sessionDirectory: $0.directory.path, files: $0.files.map(\.path),
        durationMs: $0.durationMs)
    }
  }

  private var isActive: Bool { phase == .recording || phase == .paused }

  private func finish(_ active: ActiveSession, streamAlreadyStopped: Bool) async throws
    -> EngineRecordingResult
  {
    setPhase(.stopping)
    stopTicker()
    stopLevelTicker()
    highlight.hide()
    ProcessInfo.processInfo.endActivity(active.sleepGuard)
    defer {
      session = nil
      setPhase(.idle)
    }

    let (parts, error) = await active.capture.stop(streamAlreadyStopped: streamAlreadyStopped)
    for part in parts { record(part, in: active) }
    active.manifest.status = parts.isEmpty ? .failed : .completed
    active.manifest.endedAt = Date()
    try? active.manifest.write(to: active.directory)

    guard !parts.isEmpty else {
      throw error.map { $0 is PigeonError ? $0 : EngineErrors.writerFailed($0) }
        ?? EngineErrors.writerFailed(nil)
    }
    return EngineRecordingResult(
      sessionDirectory: active.directory.path,
      files: parts.map(\.url.path),
      durationMs: parts.reduce(0) { $0 + Int64(CMTimeGetSeconds($1.duration) * 1000) },
      bytesWritten: parts.reduce(0) { $0 + $1.bytes })
  }

  /// Ends the recording on the engine's own initiative, keeping every finished part.
  private func endAfterFailure(_ error: EngineError, streamAlreadyStopped: Bool = false) {
    guard isActive, let session else { return }
    Task {
      _ = try? await finish(session, streamAlreadyStopped: streamAlreadyStopped)
      send(error)
    }
  }

  private func handleStreamStopped(_ error: Error) {
    let userStopped = (error as NSError).code == SCStreamError.userStopped.rawValue
    endAfterFailure(
      EngineError(
        code: userStopped ? "capture_stopped_by_user" : "capture_failed",
        message: userStopped
          ? "Recording was stopped from the macOS menu bar. The video was saved."
          : "Screen capture stopped: \(error.localizedDescription). The video was saved.",
        isFatal: true),
      streamAlreadyStopped: true)
  }

  private func record(_ part: SegmentedRecorder.Part) {
    guard let session else { return }
    record(part, in: session)
  }

  /// Adds a finished part to session.json (once) and saves it, so a crash loses nothing listed.
  private func record(_ part: SegmentedRecorder.Part, in active: ActiveSession) {
    guard !active.manifest.segments.contains(where: { $0.index == part.index }) else { return }
    active.manifest.segments.append(
      .init(
        index: part.index, file: part.url.lastPathComponent,
        durationMs: Int64(CMTimeGetSeconds(part.duration) * 1000), bytes: part.bytes,
        status: "complete"))
    active.manifest.segments.sort { $0.index < $1.index }
    try? active.manifest.write(to: active.directory)
  }

  private func startTicker() {
    ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }

  private func stopTicker() {
    ticker?.invalidate()
    ticker = nil
  }

  private func startLevelTicker() {
    levelTicker = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.sendLevels() }
    }
  }

  private func stopLevelTicker() {
    levelTicker?.invalidate()
    levelTicker = nil
    Task { try? await events.onAudioLevels(levels: EngineAudioLevels(system: 0, microphone: 0)) }
  }

  private func sendLevels() {
    guard isActive, let session else { return }
    let levels = session.capture.audioLevels()
    let event = EngineAudioLevels(system: levels.system ?? 0, microphone: levels.microphone ?? 0)
    Task { try? await events.onAudioLevels(levels: event) }
  }

  private func tick() {
    guard isActive, let session else { return }
    let stats = session.capture.stats()
    sendStatus(stats)
    session.ticks += 1
    if session.ticks % DiskGuard.checkEverySeconds == 0 {
      checkDiskSpace(session, stats: stats)
    }
  }

  private func checkDiskSpace(_ active: ActiveSession, stats: CaptureSession.Stats) {
    guard let space = try? DiskSpaceProbe.query(path: active.directory.path) else { return }
    let seconds = CMTimeGetSeconds(stats.elapsed)
    let bytesPerSecond = seconds > 1 ? Double(stats.bytesWritten) / seconds : 0

    switch DiskGuard.verdict(freeBytes: space.freeBytes) {
    case .ok:
      active.lowSpaceWarned = false
    case .low:
      guard !active.lowSpaceWarned else { return }
      active.lowSpaceWarned = true
      send(
        EngineError(
          code: "low_disk_space",
          message: DiskGuard.lowSpaceMessage(
            freeBytes: space.freeBytes, bytesPerSecond: bytesPerSecond),
          isFatal: false))
    case .critical:
      endAfterFailure(
        EngineError(
          code: "disk_full",
          message: "Recording stopped: the disk is almost full. Your recording was saved.",
          isFatal: true))
    }
  }

  private func setPhase(_ newPhase: EngineRecordingPhase) {
    phase = newPhase
    sendStatus(session?.capture.stats())
  }

  private func sendStatus(_ stats: CaptureSession.Stats?) {
    let status = EngineRecordingStatus(
      phase: phase,
      elapsedMs: Int64(CMTimeGetSeconds(stats?.elapsed ?? .zero) * 1000),
      segmentIndex: Int64(stats?.partIndex ?? 1),
      bytesWritten: stats?.bytesWritten ?? 0,
      droppedFrames: Int64(stats?.droppedFrames ?? 0))
    Task { try? await events.onStatus(status: status) }
  }

  private func send(_ error: EngineError) {
    Task { try? await events.onError(error: error) }
  }

  private static func filter(for display: SCDisplay, in content: SCShareableContent)
    -> SCContentFilter
  {
    let pid = ProcessInfo.processInfo.processIdentifier
    let ownApp = content.applications.filter { $0.processID == pid }
    return SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
  }

  /// Clips the area to the display; rejects areas too small to be useful.
  private static func validated(_ area: EngineCaptureArea, on display: SCDisplay) throws -> CGRect
  {
    let bounds = CGRect(x: 0, y: 0, width: display.width, height: display.height)
    let rect = CGRect(x: area.x, y: area.y, width: area.width, height: area.height)
      .intersection(bounds).integral
    guard !rect.isNull, rect.width >= AreaSelector.minimumSize,
      rect.height >= AreaSelector.minimumSize
    else {
      throw EngineErrors.make(
        "invalid_area", "The selected area is outside the screen or too small.")
    }
    return rect
  }

  private static func audioSources(for request: EngineRecordingRequest) throws -> [AudioSource] {
    var sources: [AudioSource] = []
    if request.captureSystemAudio { sources.append(.system) }
    if request.captureMicrophone {
      guard #available(macOS 15.0, *) else {
        throw EngineErrors.make(
          "unsupported", "Microphone recording needs macOS 15 or later for now.")
      }
      guard MicrophonePermission.isGranted else {
        throw EngineErrors.make(
          "microphone_permission_denied", "Microphone permission is not granted.")
      }
      sources.append(.microphone)
    }
    return sources
  }

  private static func configuration(
    width: Int, height: Int, fps: Int, sourceRect: CGRect?, audio: [AudioSource]
  ) -> SCStreamConfiguration {
    let config = SCStreamConfiguration()
    config.width = width
    config.height = height
    if let sourceRect { config.sourceRect = sourceRect }
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    config.colorMatrix = CGDisplayStream.yCbCrMatrix_ITU_R_709_2
    config.colorSpaceName = CGColorSpace.sRGB
    config.queueDepth = 5
    config.showsCursor = true
    config.capturesAudio = audio.contains(.system)
    config.sampleRate = Int(AudioPipeline.sampleRate)
    config.channelCount = 2
    config.excludesCurrentProcessAudio = true
    if #available(macOS 15.0, *) {
      config.captureMicrophone = audio.contains(.microphone)
    }
    return config
  }

  /// Removes a session folder that holds nothing but its (just created) manifest.
  private static func removeIfUnused(_ directory: URL) {
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    if contents.allSatisfy({ $0 == SessionManifest.fileName }) {
      try? FileManager.default.removeItem(at: directory)
    }
  }
}

enum OutputSize {
  /// Scales down to `maxHeight` keeping aspect ratio; H.264 needs even dimensions.
  static func fit(width: Int, height: Int, maxHeight: Int) -> (width: Int, height: Int) {
    guard height > maxHeight, maxHeight > 0 else { return (even(width), even(height)) }
    let scaledWidth = Double(width) * Double(maxHeight) / Double(height)
    return (even(Int(scaledWidth.rounded())), even(maxHeight))
  }

  private static func even(_ value: Int) -> Int { value - value % 2 }
}
