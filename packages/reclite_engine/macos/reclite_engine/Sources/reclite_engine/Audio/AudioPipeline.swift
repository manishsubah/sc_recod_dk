import CoreMedia

/// Turns audio from up to two sources into one mixed 48 kHz stereo stream, aligned
/// to the video session start. Use from one serial queue.
final class AudioPipeline {
  static let sampleRate: Int32 = 48_000

  /// How long to wait for a quiet source before filling it with silence.
  static let maxLag = CMTime(value: 250, timescale: 1000)

  let meter: LevelMeter
  private let sourceCount: Int
  private let mixer: AudioMixer
  private let normalizers: [AudioNormalizer]
  private let output: (CMSampleBuffer) -> Void
  private var origin: CMTime?

  init(sourceCount: Int, output: @escaping (CMSampleBuffer) -> Void) {
    self.sourceCount = sourceCount
    self.output = output
    meter = LevelMeter(sourceCount: sourceCount)
    mixer = AudioMixer(sourceCount: sourceCount)
    normalizers = (0..<sourceCount).map { _ in AudioNormalizer() }
  }

  /// Timeline zero: the first video frame. Audio before it is dropped.
  func start(at origin: CMTime) {
    if self.origin == nil { self.origin = origin }
  }

  func push(source: Int, _ sampleBuffer: CMSampleBuffer) {
    guard let samples = normalizers[source].convert(sampleBuffer) else { return }
    meter.record(source: source, samples: samples)
    guard let origin else { return }
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    mixer.push(source: source, samples: samples, startFrame: Self.frame(pts, from: origin))
  }

  /// Emits what every source has delivered, or up to `now - maxLag` when one is quiet.
  func pump(now: CMTime) {
    guard let origin else { return }
    let nowFrame = Self.frame(now, from: origin)
    let lagFrame = nowFrame - Self.frame(Self.maxLag, from: .zero)
    let ready = (0..<sourceCount).map { mixer.endFrame(of: $0) ?? mixer.outputFrame }.min() ?? 0
    emit(until: min(nowFrame, max(ready, lagFrame)))
  }

  /// Emits everything up to `end`, filling missing audio with silence.
  func flush(until end: CMTime) {
    guard let origin else { return }
    emit(until: Self.frame(end, from: origin))
  }

  private func emit(until frame: Int64) {
    guard let origin, frame > mixer.outputFrame else { return }
    let first = mixer.outputFrame
    let samples = mixer.pull(until: frame)
    let pts = CMTimeAdd(origin, CMTime(value: first, timescale: Self.sampleRate))
    if let buffer = AudioSampleBuffers.make(samples, presentationTime: pts) {
      output(buffer)
    }
  }

  private static func frame(_ time: CMTime, from origin: CMTime) -> Int64 {
    let seconds = CMTimeGetSeconds(CMTimeSubtract(time, origin))
    return Int64((seconds * Double(sampleRate)).rounded())
  }
}
