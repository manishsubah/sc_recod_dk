import AVFoundation

/// Encodes one MP4 part. Not thread-safe: use from a single serial queue.
///
/// Writes to `<name>.mp4.part` with a movie fragment every 2 s of recording, so a crash
/// leaves a file playable up to the last fragment; renamed to `<name>.mp4` when finished.
final class SegmentWriter {
  static let fragmentInterval = CMTime(seconds: 2, preferredTimescale: 600)

  let index: Int
  let finalURL: URL
  let partURL: URL
  private let writer: AVAssetWriter
  private let videoInput: AVAssetWriterInput
  private let audioInput: AVAssetWriterInput?

  private(set) var firstPTS: CMTime = .invalid
  private(set) var lastPTS: CMTime = .invalid
  private(set) var droppedFrames = 0
  private(set) var droppedAudioBuffers = 0

  /// Kept so the final frame can be repeated at the stop time (one buffer, not a queue).
  private(set) var lastBuffer: CMSampleBuffer?

  init(index: Int, url: URL, width: Int, height: Int, framesPerSecond: Int, withAudio: Bool)
    throws
  {
    self.index = index
    finalURL = url
    partURL = url.appendingPathExtension("part")

    writer = try AVAssetWriter(outputURL: partURL, fileType: .mp4)
    writer.movieFragmentInterval = Self.fragmentInterval
    writer.shouldOptimizeForNetworkUse = false

    videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: Self.videoSettings(width: width, height: height, fps: framesPerSecond))
    videoInput.expectsMediaDataInRealTime = true

    guard writer.canAdd(videoInput) else { throw EngineErrors.writerFailed(writer.error) }
    writer.add(videoInput)

    if withAudio {
      let input = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.audioSettings)
      input.expectsMediaDataInRealTime = true
      guard writer.canAdd(input) else { throw EngineErrors.writerFailed(writer.error) }
      writer.add(input)
      audioInput = input
    } else {
      audioInput = nil
    }
    guard writer.startWriting() else { throw EngineErrors.writerFailed(writer.error) }
  }

  var hasFailed: Bool { writer.status == .failed }
  var failure: Error? { writer.error }

  /// Media time where this part begins; audio and video before it are dropped.
  var sessionStart: CMTime? { firstPTS.isValid ? firstPTS : nil }

  var bytesOnDisk: Int64 {
    let size = try? FileManager.default.attributesOfItem(atPath: partURL.path)[.size] as? NSNumber
    return size?.int64Value ?? 0
  }

  /// Later parts start at the exact boundary rather than at their first frame.
  func startSession(at time: CMTime) {
    guard !firstPTS.isValid else { return }
    writer.startSession(atSourceTime: time)
    firstPTS = time
  }

  /// Shows `buffer`'s picture from `time`, so a part never opens on a blank screen.
  func seed(with buffer: CMSampleBuffer, at time: CMTime) {
    guard let copy = Self.retimed(buffer, to: time) else { return }
    appendVideo(copy)
  }

  /// Back-pressure: if the encoder is busy the frame is dropped, never queued.
  func appendVideo(_ buffer: CMSampleBuffer) {
    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
    if !firstPTS.isValid {
      startSession(at: pts)
    }
    guard CMTimeCompare(pts, firstPTS) >= 0,
      !lastPTS.isValid || CMTimeCompare(pts, lastPTS) > 0
    else { return }
    guard videoInput.isReadyForMoreMediaData, videoInput.append(buffer) else {
      droppedFrames += 1
      return
    }
    lastPTS = pts
    lastBuffer = buffer
  }

  func appendAudio(_ buffer: CMSampleBuffer) {
    guard let audioInput, firstPTS.isValid else { return }
    guard audioInput.isReadyForMoreMediaData, audioInput.append(buffer) else {
      droppedAudioBuffers += 1
      return
    }
  }

  func finish(at end: CMTime, completion: @escaping (Result<URL, Error>) -> Void) {
    guard firstPTS.isValid, lastPTS.isValid else {
      writer.cancelWriting()
      try? FileManager.default.removeItem(at: partURL)
      completion(.failure(EngineErrors.make("writer_failed", "No video frames were captured.")))
      return
    }

    repeatLastFrame(at: end)
    lastBuffer = nil
    videoInput.markAsFinished()
    audioInput?.markAsFinished()
    writer.endSession(atSourceTime: CMTimeMaximum(end, lastPTS))
    writer.finishWriting { [writer, partURL, finalURL] in
      guard writer.status == .completed else {
        completion(.failure(EngineErrors.writerFailed(writer.error)))
        return
      }
      do {
        try FileManager.default.moveItem(at: partURL, to: finalURL)
        completion(.success(finalURL))
      } catch {
        completion(.failure(EngineErrors.writerFailed(error)))
      }
    }
  }

  /// Discards a part that never received frames (e.g. a pre-created next part at Stop).
  func cancel() {
    writer.cancelWriting()
    try? FileManager.default.removeItem(at: partURL)
  }

  func duration(until end: CMTime) -> CMTime {
    guard firstPTS.isValid else { return .zero }
    return CMTimeSubtract(CMTimeMaximum(end, lastPTS), firstPTS)
  }

  static func retimed(_ buffer: CMSampleBuffer, to time: CMTime) -> CMSampleBuffer? {
    var timing = CMSampleTimingInfo(
      duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
    var copy: CMSampleBuffer?
    guard
      CMSampleBufferCreateCopyWithNewTiming(
        allocator: kCFAllocatorDefault, sampleBuffer: buffer, sampleTimingEntryCount: 1,
        sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr
    else { return nil }
    return copy
  }

  /// endSession(atSourceTime:) does not stretch the last frame: a screen that stayed
  /// still before Stop would be cut off. Re-appending the last frame at `end` keeps it.
  private func repeatLastFrame(at end: CMTime) {
    guard let lastBuffer, CMTimeCompare(end, lastPTS) > 0,
      let copy = Self.retimed(lastBuffer, to: end)
    else { return }
    for _ in 0..<50 where !videoInput.isReadyForMoreMediaData {
      usleep(2_000)
    }
    if videoInput.isReadyForMoreMediaData, videoInput.append(copy) {
      lastPTS = end
    }
  }

  private static func videoSettings(width: Int, height: Int, fps: Int) -> [String: Any] {
    [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ],
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate(width: width, height: height, fps: fps),
        AVVideoMaxKeyFrameIntervalDurationKey: 2,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: false,
      ],
    ]
  }

  private static let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 48_000,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 160_000,
  ]

  /// ~0.08 bits per pixel per frame (≈5 Mbps at 1080p30), clamped for tiny/huge outputs.
  static func bitrate(width: Int, height: Int, fps: Int) -> Int {
    let raw = Double(width * height * fps) * 0.08
    return Int(min(max(raw, 400_000), 16_000_000))
  }
}
