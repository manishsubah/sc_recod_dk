import CoreMedia

/// Turns audio from up to two sources into one mixed 48 kHz stereo stream on the
/// recording's media timeline. Use from one serial queue.
final class AudioPipeline {
  static let sampleRate: Int32 = 48_000

  /// How long to wait for a quiet source before filling it with silence.
  static let maxLag = CMTime(value: 250, timescale: 1000)

  let meter: LevelMeter

  /// Receives each mixed buffer, in order. Never straddles the boundary.
  var onBuffer: ((CMSampleBuffer) -> Void)?

  private let sourceCount: Int
  private let mixer: AudioMixer
  private let normalizers: [AudioNormalizer]
  private var origin: CMTime?
  private var boundaryFrame: Int64?
  private var onBoundary: ((CMTime) -> Void)?

  init(sourceCount: Int) {
    self.sourceCount = sourceCount
    meter = LevelMeter(sourceCount: sourceCount)
    mixer = AudioMixer(sourceCount: sourceCount)
    normalizers = (0..<sourceCount).map { _ in AudioNormalizer() }
  }

  /// Media time up to which audio has been emitted.
  var outputTime: CMTime? {
    origin.map { CMTimeAdd($0, CMTime(value: mixer.outputFrame, timescale: Self.sampleRate)) }
  }

  /// Timeline zero: the first video frame. Audio before it is dropped.
  func start(at origin: CMTime) {
    if self.origin == nil { self.origin = origin }
  }

  /// Splits output exactly at `time`; `reached` runs after the last sample before it.
  func setBoundary(at time: CMTime, reached: @escaping (CMTime) -> Void) {
    guard let origin else { return }
    boundaryFrame = Self.frame(time, from: origin)
    onBoundary = reached
    fireBoundaryIfReached()
  }

  /// `time` is the buffer's position on the media timeline (pauses removed).
  func push(source: Int, _ sampleBuffer: CMSampleBuffer, at time: CMTime) {
    guard let samples = normalizers[source].convert(sampleBuffer) else { return }
    meter.record(source: source, samples: samples)
    guard let origin else { return }
    mixer.push(source: source, samples: samples, startFrame: Self.frame(time, from: origin))
  }

  /// Emits what every source has delivered, or up to `now - maxLag` when one is quiet.
  /// Never goes past `ceiling` (the pause point while paused).
  func pump(now: CMTime, ceiling: CMTime? = nil) {
    guard let origin else { return }
    let nowFrame = Self.frame(now, from: origin)
    let lagFrame = nowFrame - Self.frame(Self.maxLag, from: .zero)
    let ready = (0..<sourceCount).map { mixer.endFrame(of: $0) ?? mixer.outputFrame }.min() ?? 0
    var target = min(nowFrame, max(ready, lagFrame))
    if let ceiling { target = min(target, Self.frame(ceiling, from: origin)) }
    emit(until: target)
  }

  /// Emits everything up to `end`, filling missing audio with silence.
  func flush(until end: CMTime) {
    guard let origin else { return }
    emit(until: Self.frame(end, from: origin))
  }

  private func emit(until frame: Int64) {
    guard let origin else { return }
    while frame > mixer.outputFrame {
      var end = frame
      if let boundaryFrame, boundaryFrame > mixer.outputFrame, boundaryFrame < end {
        end = boundaryFrame
      }
      let first = mixer.outputFrame
      let samples = mixer.pull(until: end)
      let pts = CMTimeAdd(origin, CMTime(value: first, timescale: Self.sampleRate))
      if let buffer = AudioSampleBuffers.make(samples, presentationTime: pts) {
        onBuffer?(buffer)
      }
      fireBoundaryIfReached()
    }
  }

  private func fireBoundaryIfReached() {
    guard let boundaryFrame, let origin, mixer.outputFrame >= boundaryFrame else { return }
    let callback = onBoundary
    self.boundaryFrame = nil
    onBoundary = nil
    callback?(CMTimeAdd(origin, CMTime(value: boundaryFrame, timescale: Self.sampleRate)))
  }

  private static func frame(_ time: CMTime, from origin: CMTime) -> Int64 {
    let seconds = CMTimeGetSeconds(CMTimeSubtract(time, origin))
    return Int64((seconds * Double(sampleRate)).rounded())
  }
}
