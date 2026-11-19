import CoreMedia
import Foundation

/// One recording written as consecutive MP4 parts, with pause/resume.
///
/// Inputs carry host-clock times (ScreenCaptureKit's clock). Internally everything
/// runs on a media timeline with paused time removed, so parts and audio stay
/// continuous. Call every method on `queue`.
final class SegmentedRecorder {
  struct Settings {
    let segmentDuration: CMTime
    let width: Int
    let height: Int
    let framesPerSecond: Int
    let audioSourceCount: Int
    /// File for part `index`, expected to start at wall-clock `date`.
    let makeURL: (_ index: Int, _ date: Date) -> URL
  }

  struct Part: Equatable {
    let index: Int
    let url: URL
    let duration: CMTime
    let bytes: Int64
  }

  /// The next part's writer is created this long before the boundary, off the hot path.
  static let prewarmLead = CMTime(seconds: 10, preferredTimescale: 600)

  /// With no new frames and no audio, the boundary is enforced this long after it passes.
  static let rotationGrace = CMTime(value: 500, timescale: 1000)

  let audio: AudioPipeline?

  /// Runs on `queue` after each part is closed and renamed to `.mp4`.
  var onPartFinished: ((Part) -> Void)?

  /// Runs on `queue` the first time writing fails; the recording should then be stopped.
  var onFailure: ((Error) -> Void)?

  private let settings: Settings
  private let queue: DispatchQueue
  private let finishing = DispatchGroup()

  private var writer: SegmentWriter
  private var audioTarget: SegmentWriter
  private var draining: (writer: SegmentWriter, end: CMTime)?
  private var prepared: SegmentWriter?
  private var partStart: CMTime?
  private(set) var origin: CMTime?
  private var pauseOffset = CMTime.zero
  private var pausedAt: CMTime?
  private var stopped = false
  private(set) var parts: [Part] = []
  private var completedBytes: Int64 = 0
  private var completedDrops = 0
  private(set) var failure: Error?

  init(settings: Settings, queue: DispatchQueue) throws {
    self.settings = settings
    self.queue = queue
    writer = try Self.makeWriter(settings, index: 1, startsIn: 0)
    audioTarget = writer
    audio =
      settings.audioSourceCount > 0 ? AudioPipeline(sourceCount: settings.audioSourceCount) : nil
    audio?.onBuffer = { [weak self] buffer in self?.audioTarget.appendAudio(buffer) }
  }

  var partIndex: Int { writer.index }
  var isPaused: Bool { pausedAt != nil }
  var droppedFrames: Int { completedDrops + writer.droppedFrames }
  var bytesWritten: Int64 {
    completedBytes + writer.bytesOnDisk + (draining?.writer.bytesOnDisk ?? 0)
  }

  /// Recorded time so far, pauses excluded.
  func elapsed(hostNow: CMTime) -> CMTime {
    guard let origin else { return .zero }
    return CMTimeMaximum(.zero, CMTimeSubtract(media(pausedAt ?? hostNow), origin))
  }

  func appendVideo(_ buffer: CMSampleBuffer) {
    guard !stopped, failure == nil else { return }
    let hostPTS = CMSampleBufferGetPresentationTimeStamp(buffer)
    if let pausedAt, CMTimeCompare(hostPTS, pausedAt) >= 0 { return }
    let pts = media(hostPTS)

    if let boundary, CMTimeCompare(pts, boundary) >= 0 {
      rotate(at: boundary)
    }
    guard let timed = pauseOffset == .zero ? buffer : SegmentWriter.retimed(buffer, to: pts)
    else { return }
    writer.appendVideo(timed)

    if origin == nil, let start = writer.sessionStart {
      origin = start
      partStart = start
      audio?.start(at: start)
      armAudioBoundary()
    }
  }

  func appendAudio(source: Int, _ buffer: CMSampleBuffer, hostNow: CMTime) {
    guard !stopped, failure == nil, let audio else { return }
    let hostPTS = CMSampleBufferGetPresentationTimeStamp(buffer)
    if let pausedAt, CMTimeCompare(hostPTS, pausedAt) >= 0 { return }
    audio.push(source: source, buffer, at: media(hostPTS))
    pumpAudio(hostNow: hostNow)
  }

  /// Call about every 100 ms: keeps audio flowing, prepares and enforces part boundaries.
  func tick(hostNow: CMTime) {
    guard !stopped, failure == nil, partStart != nil else { return }
    pumpAudio(hostNow: hostNow)
    guard let boundary else { return }

    let now = media(pausedAt ?? hostNow)
    let untilBoundary = CMTimeSubtract(boundary, now)
    if prepared == nil, CMTimeCompare(untilBoundary, Self.prewarmLead) <= 0 {
      prepared = try? Self.makeWriter(
        settings, index: writer.index + 1, startsIn: max(0, CMTimeGetSeconds(untilBoundary)))
    }
    if !isPaused, CMTimeCompare(now, CMTimeAdd(boundary, Self.rotationGrace)) >= 0 {
      rotate(at: boundary)
    }
  }

  func pause(hostNow: CMTime) {
    guard !stopped, pausedAt == nil else { return }
    pausedAt = hostNow
  }

  func resume(hostNow: CMTime) {
    guard let pausedAt else { return }
    pauseOffset = CMTimeAdd(pauseOffset, CMTimeMaximum(.zero, CMTimeSubtract(hostNow, pausedAt)))
    self.pausedAt = nil
  }

  /// Closes every open part. `completion` runs on `queue` with all finished parts.
  func stop(hostNow: CMTime, completion: @escaping ([Part], Error?) -> Void) {
    guard !stopped else { return }
    stopped = true
    let end = media(pausedAt ?? hostNow)

    audio?.flush(until: end)
    if let draining {
      finishPart(draining.writer, at: draining.end)
      self.draining = nil
    }
    prepared?.cancel()
    prepared = nil
    finishPart(writer, at: CMTimeMaximum(end, partStart ?? end))

    finishing.notify(queue: queue) { [weak self] in
      guard let self else { return }
      completion(self.parts.sorted { $0.index < $1.index }, self.failure)
    }
  }

  private var boundary: CMTime? {
    partStart.map { CMTimeAdd($0, settings.segmentDuration) }
  }

  private func media(_ hostTime: CMTime) -> CMTime {
    CMTimeSubtract(hostTime, pauseOffset)
  }

  private func pumpAudio(hostNow: CMTime) {
    audio?.pump(now: media(hostNow), ceiling: pausedAt.map(media))
  }

  /// Starts the next part at `time`. Audio before `time` keeps going to the old part
  /// until the mix reaches the boundary.
  private func rotate(at time: CMTime) {
    guard !stopped, failure == nil, draining == nil else { return }
    let next: SegmentWriter
    do {
      next = try prepared ?? Self.makeWriter(settings, index: writer.index + 1, startsIn: 0)
    } catch {
      fail(error)
      return
    }
    prepared = nil

    let old = writer
    next.startSession(at: time)
    if let last = old.lastBuffer { next.seed(with: last, at: time) }
    writer = next
    partStart = time

    if let audio, let emitted = audio.outputTime, CMTimeCompare(emitted, time) < 0 {
      draining = (old, time)
    } else {
      audioTarget = next
      finishPart(old, at: time)
      armAudioBoundary()
    }
  }

  private func armAudioBoundary() {
    guard let audio, let boundary else { return }
    audio.setBoundary(at: boundary) { [weak self] _ in self?.audioReachedBoundary() }
  }

  private func audioReachedBoundary() {
    if let draining {
      audioTarget = writer
      finishPart(draining.writer, at: draining.end)
      self.draining = nil
      armAudioBoundary()
    } else if let boundary {
      rotate(at: boundary)
    }
  }

  private func finishPart(_ part: SegmentWriter, at end: CMTime) {
    finishing.enter()
    let group = finishing
    let duration = part.duration(until: end)
    let drops = part.droppedFrames
    part.finish(at: end) { [weak self, queue] result in
      queue.async {
        defer { group.leave() }
        guard let self else { return }
        switch result {
        case .success(let url):
          let bytes =
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?
            .int64Value ?? 0
          let finished = Part(index: part.index, url: url, duration: duration, bytes: bytes)
          self.parts.append(finished)
          self.completedBytes += bytes
          self.completedDrops += drops
          self.onPartFinished?(finished)
        case .failure(let error):
          self.fail(error)
        }
      }
    }
  }

  private func fail(_ error: Error) {
    guard failure == nil else { return }
    failure = error
    onFailure?(error)
  }

  private static func makeWriter(_ settings: Settings, index: Int, startsIn seconds: Double)
    throws -> SegmentWriter
  {
    try SegmentWriter(
      index: index,
      url: settings.makeURL(index, Date().addingTimeInterval(seconds)),
      width: settings.width, height: settings.height,
      framesPerSecond: settings.framesPerSecond,
      withAudio: settings.audioSourceCount > 0)
  }
}
