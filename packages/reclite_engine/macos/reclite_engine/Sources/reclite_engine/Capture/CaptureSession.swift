import CoreMedia
import ScreenCaptureKit

enum AudioSource {
  case system
  case microphone
}

/// One SCStream feeding one SegmentWriter. Frames, audio and the writer stay on `queue`.
final class CaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
  struct Stats {
    let bytesOnDisk: Int64
    let droppedFrames: Int
    let writerFailure: Error?
  }

  private static let pumpInterval: DispatchTimeInterval = .milliseconds(100)

  private let queue = DispatchQueue(label: "app.reclite.capture", qos: .userInteractive)
  private let filter: SCContentFilter
  private let configuration: SCStreamConfiguration
  private let writer: SegmentWriter
  private let audioSources: [AudioSource]
  private let audio: AudioPipeline?
  private var pumpTimer: DispatchSourceTimer?
  private var stream: SCStream?
  private var isFinishing = false

  /// Called on the main thread when macOS ends the stream (e.g. the user stops sharing).
  var onStreamStopped: ((Error) -> Void)?

  init(
    filter: SCContentFilter, configuration: SCStreamConfiguration, writer: SegmentWriter,
    audioSources: [AudioSource]
  ) {
    self.filter = filter
    self.configuration = configuration
    self.writer = writer
    self.audioSources = audioSources
    audio =
      audioSources.isEmpty
      ? nil
      : AudioPipeline(sourceCount: audioSources.count) { [writer] buffer in
        writer.appendAudio(buffer)
      }
    super.init()
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
    startPumping()
  }

  func stats() -> Stats {
    queue.sync {
      Stats(
        bytesOnDisk: writer.bytesOnDisk,
        droppedFrames: writer.droppedFrames,
        writerFailure: writer.hasFailed ? writer.failure : nil)
    }
  }

  /// Peak levels since the last call, 0…1. Nil source = not being recorded.
  func audioLevels() -> (system: Double?, microphone: Double?) {
    guard let audio else { return (nil, nil) }
    let levels = audio.meter.takeLevels()
    let level = { (source: AudioSource) in
      self.audioSources.firstIndex(of: source).map { levels[$0] }
    }
    return (level(.system), level(.microphone))
  }

  /// Stops capture and finalizes the MP4. Returns the file and its media duration.
  func stop(streamAlreadyStopped: Bool = false) async throws -> (url: URL, duration: CMTime) {
    if !streamAlreadyStopped {
      try? await stream?.stopCapture()
    }
    stream = nil
    return try await withCheckedThrowingContinuation { continuation in
      queue.async { [writer, audio] in
        self.isFinishing = true
        self.pumpTimer?.cancel()
        self.pumpTimer = nil
        let end = CMClockGetTime(CMClockGetHostTimeClock())
        audio?.flush(until: end)
        let duration = writer.duration(until: end)
        writer.finish(at: end) { result in
          continuation.resume(with: result.map { ($0, duration) })
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
      guard Self.isCompleteFrame(sampleBuffer) else { return }
      writer.appendVideo(sampleBuffer)
      if let start = writer.sessionStart { audio?.start(at: start) }
    case .audio:
      push(.system, sampleBuffer)
    default:
      if #available(macOS 15.0, *), type == .microphone {
        push(.microphone, sampleBuffer)
      }
    }
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    DispatchQueue.main.async { self.onStreamStopped?(error) }
  }

  private func push(_ source: AudioSource, _ buffer: CMSampleBuffer) {
    guard let audio, let index = audioSources.firstIndex(of: source) else { return }
    audio.push(source: index, buffer)
    audio.pump(now: CMClockGetTime(CMClockGetHostTimeClock()))
  }

  /// Keeps audio flowing (as silence) when every source is quiet, e.g. nothing is playing.
  private func startPumping() {
    guard let audio else { return }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + Self.pumpInterval, repeating: Self.pumpInterval)
    timer.setEventHandler { [weak self] in
      guard let self, !self.isFinishing else { return }
      audio.pump(now: CMClockGetTime(CMClockGetHostTimeClock()))
    }
    timer.resume()
    queue.async { self.pumpTimer = timer }
  }

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
