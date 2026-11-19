import CoreMedia
import Foundation
import ScreenCaptureKit

/// Owns the recording lifecycle. All state lives on the main actor; frames never do.
@MainActor
final class RecordingEngine {
  private struct ActiveSession {
    let capture: CaptureSession
    let directory: URL
    let startedAt: Date
  }

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

      let startedAt = Date()
      let sessionDirectory = try SessionNaming.createSessionDirectory(
        in: URL(fileURLWithPath: request.outputDirectory, isDirectory: true), startedAt: startedAt)
      directory = sessionDirectory

      let writer = try SegmentWriter(
        url: sessionDirectory.appendingPathComponent(
          SessionNaming.segmentFileName(startedAt: startedAt, index: 1)),
        width: size.width, height: size.height, framesPerSecond: fps,
        withAudio: !audioSources.isEmpty)

      let capture = CaptureSession(
        filter: Self.filter(for: display, in: content),
        configuration: Self.configuration(
          width: size.width, height: size.height, fps: fps, sourceRect: area,
          audio: audioSources),
        writer: writer,
        audioSources: audioSources)
      capture.onStreamStopped = { [weak self] error in
        Task { await self?.handleStreamStopped(error) }
      }
      try await capture.start()

      if let area, let screen = DisplayCatalog.screen(for: display.displayID) {
        highlight.show(area, on: screen)
      }

      session = ActiveSession(capture: capture, directory: sessionDirectory, startedAt: startedAt)
      setPhase(.recording)
      startTicker()
      if !audioSources.isEmpty { startLevelTicker() }
      return EngineRecordingSession(
        sessionDirectory: sessionDirectory.path, width: Int64(size.width),
        height: Int64(size.height))
    } catch {
      if let directory { Self.removeIfEmpty(directory) }
      setPhase(.idle)
      throw error is PigeonError ? error : EngineErrors.captureFailed(error)
    }
  }

  func stop() async throws -> EngineRecordingResult {
    guard phase == .recording, let session else { throw EngineErrors.notRecording }
    return try await finish(session, streamAlreadyStopped: false)
  }

  private func finish(_ active: ActiveSession, streamAlreadyStopped: Bool) async throws
    -> EngineRecordingResult
  {
    setPhase(.stopping)
    stopTicker()
    stopLevelTicker()
    highlight.hide()
    defer {
      session = nil
      setPhase(.idle)
    }

    let (url, duration) = try await active.capture.stop(streamAlreadyStopped: streamAlreadyStopped)
    let bytes =
      (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?
      .int64Value ?? 0
    return EngineRecordingResult(
      sessionDirectory: active.directory.path,
      files: [url.path],
      durationMs: Int64(CMTimeGetSeconds(duration) * 1000),
      bytesWritten: bytes)
  }

  private func handleStreamStopped(_ error: Error) async {
    guard phase == .recording, let session else { return }
    let userStopped = (error as NSError).code == SCStreamError.userStopped.rawValue
    _ = try? await finish(session, streamAlreadyStopped: true)
    send(
      EngineError(
        code: userStopped ? "capture_stopped_by_user" : "capture_failed",
        message: userStopped
          ? "Recording was stopped from the macOS menu bar. The video was saved."
          : "Screen capture stopped: \(error.localizedDescription). The video was saved.",
        isFatal: true))
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
    guard phase == .recording, let session else { return }
    let levels = session.capture.audioLevels()
    let event = EngineAudioLevels(system: levels.system ?? 0, microphone: levels.microphone ?? 0)
    Task { try? await events.onAudioLevels(levels: event) }
  }

  private func tick() {
    guard phase == .recording, let session else { return }
    let stats = session.capture.stats()
    if let failure = stats.writerFailure {
      Task {
        _ = try? await finish(session, streamAlreadyStopped: false)
        send(EngineError(code: "writer_failed", message: failure.localizedDescription, isFatal: true))
      }
      return
    }
    sendStatus(bytes: stats.bytesOnDisk, dropped: stats.droppedFrames)
  }

  private func setPhase(_ newPhase: EngineRecordingPhase) {
    phase = newPhase
    sendStatus(bytes: 0, dropped: 0)
  }

  private func sendStatus(bytes: Int64, dropped: Int) {
    let elapsed = session.map { Date().timeIntervalSince($0.startedAt) } ?? 0
    let status = EngineRecordingStatus(
      phase: phase,
      elapsedMs: Int64(elapsed * 1000),
      segmentIndex: 1,
      bytesWritten: bytes,
      droppedFrames: Int64(dropped))
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
      throw EngineErrors.make("invalid_area", "The selected area is outside the screen or too small.")
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

  private static func removeIfEmpty(_ directory: URL) {
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    if contents.isEmpty { try? FileManager.default.removeItem(at: directory) }
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
