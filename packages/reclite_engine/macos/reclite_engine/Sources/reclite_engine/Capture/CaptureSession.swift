import CoreMedia
import ScreenCaptureKit

enum AudioSource {
  case system
  case microphone
}

/// Feeds one SCStream into a SegmentedRecorder. Frames, audio and writers stay on `queue`.
final class CaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
  struct Stats {
    let elapsed: CMTime
    let partIndex: Int
    let bytesWritten: Int64
    let droppedFrames: Int
    let failure: Error?
  }

  private static let tickInterval: DispatchTimeInterval = .milliseconds(100)

  private let queue = DispatchQueue(label: "app.reclite.capture", qos: .userInteractive)
  private let filter: SCContentFilter
  private let configuration: SCStreamConfiguration
  private let audioSources: [AudioSource]
  private let recorder: SegmentedRecorder
  private var ticker: DispatchSourceTimer?
  private var stream: SCStream?
  private var isFinishing = false

  /// Main thread: macOS ended the stream (e.g. the user stopped sharing from the menu bar).
  var onStreamStopped: ((Error) -> Void)?

  /// Main thread: a part was closed and renamed to `.mp4`.
  var onPartFinished: ((SegmentedRecorder.Part) -> Void)?

  /// Main thread: writing failed (disk full, encoder error); the recording must stop.
  var onWriteFailure: ((Error) -> Void)?

  init(
    filter: SCContentFilter, configuration: SCStreamConfiguration,
    settings: SegmentedRecorder.Settings, audioSources: [AudioSource]
  ) throws {
    self.filter = filter
    self.configuration = configuration
    self.audioSources = audioSources
    recorder = try SegmentedRecorder(settings: settings, queue: queue)
    super.init()
    recorder.onPartFinished = { [weak self] part in
      DispatchQueue.main.async { self?.onPartFinished?(part) }
    }
    recorder.onFailure = { [weak self] error in
      DispatchQueue.main.async { self?.onWriteFailure?(error) }
    }
  }

  func start() async throws {
    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
    if audioSources.contains(.system) {
      try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
    }
    if #available(macOS 15.0, *), audioSources.contains(.microphone) {
      try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
    }
    try await stream.startCapture()
    self.stream = stream
    startTicking()
  }

  func stats() -> Stats {
    queue.sync {
      Stats(
        elapsed: recorder.elapsed(hostNow: Self.hostNow),
        partIndex: recorder.partIndex,
        bytesWritten: recorder.bytesWritten,
        droppedFrames: recorder.droppedFrames,
        failure: recorder.failure)
    }
  }

  func pause() { queue.async { self.recorder.pause(hostNow: Self.hostNow) } }

  func resume() { queue.async { self.recorder.resume(hostNow: Self.hostNow) } }

  /// Peak levels since the last call, 0…1. Nil source = not being recorded.
  func audioLevels() -> (system: Double?, microphone: Double?) {
    guard let meter = recorder.audio?.meter else { return (nil, nil) }
    let levels = meter.takeLevels()
    let level = { (source: AudioSource) in
      self.audioSources.firstIndex(of: source).map { levels[$0] }
    }
    return (level(.system), level(.microphone))
  }

  /// Stops capture and closes every part. Returns all finished parts in order.
  func stop(streamAlreadyStopped: Bool = false) async -> (parts: [SegmentedRecorder.Part], error: Error?) {
    if !streamAlreadyStopped {
      try? await stream?.stopCapture()
    }
    stream = nil
    return await withCheckedContinuation { continuation in
      queue.async {
        self.isFinishing = true
        self.ticker?.cancel()
        self.ticker = nil
        self.recorder.stop(hostNow: Self.hostNow) { parts, error in
          continuation.resume(returning: (parts, error))
        }
      }
    }
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of type: SCStreamOutputType
  ) {
    guard !isFinishing, sampleBuffer.isValid else { return }
    switch type {
    case .screen:
      if Self.isCompleteFrame(sampleBuffer) { recorder.appendVideo(sampleBuffer) }
    case .audio:
      appendAudio(.system, sampleBuffer)
    default:
      if #available(macOS 15.0, *), type == .microphone {
        appendAudio(.microphone, sampleBuffer)
      }
    }
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    DispatchQueue.main.async { self.onStreamStopped?(error) }
  }

  private func appendAudio(_ source: AudioSource, _ buffer: CMSampleBuffer) {
    guard let index = audioSources.firstIndex(of: source) else { return }
    recorder.appendAudio(source: index, buffer, hostNow: Self.hostNow)
  }

  private func startTicking() {
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + Self.tickInterval, repeating: Self.tickInterval)
    timer.setEventHandler { [weak self] in
      guard let self, !self.isFinishing else { return }
      self.recorder.tick(hostNow: Self.hostNow)
    }
    timer.resume()
    queue.async { self.ticker = timer }
  }

  private static var hostNow: CMTime { CMClockGetTime(CMClockGetHostTimeClock()) }

  /// SCK also delivers idle/blank frames when nothing changed; only complete frames carry pixels.
  private static func isCompleteFrame(_ buffer: CMSampleBuffer) -> Bool {
    guard
      let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
        as? [[SCStreamFrameInfo: Any]],
      let rawStatus = attachments.first?[.status] as? Int,
      let status = SCFrameStatus(rawValue: rawStatus)
    else { return false }
    return status == .complete
  }
}
