import CoreMedia
import ScreenCaptureKit

/// One SCStream feeding one SegmentWriter. Frames and the writer stay on `queue`.
final class CaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
  struct Stats {
    let bytesOnDisk: Int64
    let droppedFrames: Int
    let writerFailure: Error?
  }

  private let queue = DispatchQueue(label: "app.reclite.capture", qos: .userInteractive)
  private let filter: SCContentFilter
  private let configuration: SCStreamConfiguration
  private let writer: SegmentWriter
  private var stream: SCStream?
  private var isFinishing = false

  /// Called on the main thread when macOS ends the stream (e.g. the user stops sharing).
  var onStreamStopped: ((Error) -> Void)?

  init(filter: SCContentFilter, configuration: SCStreamConfiguration, writer: SegmentWriter) {
    self.filter = filter
    self.configuration = configuration
    self.writer = writer
    super.init()
  }

  func start() async throws {
    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
    try await stream.startCapture()
    self.stream = stream
  }

  func stats() -> Stats {
    queue.sync {
      Stats(
        bytesOnDisk: writer.bytesOnDisk,
        droppedFrames: writer.droppedFrames,
        writerFailure: writer.hasFailed ? writer.failure : nil)
    }
  }

  /// Stops capture and finalizes the MP4. Returns the file and its media duration.
  func stop(streamAlreadyStopped: Bool = false) async throws -> (url: URL, duration: CMTime) {
    if !streamAlreadyStopped {
      try? await stream?.stopCapture()
    }
    stream = nil
    return try await withCheckedThrowingContinuation { continuation in
      queue.async { [writer] in
        self.isFinishing = true
        let end = CMClockGetTime(CMClockGetHostTimeClock())
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
    guard type == .screen, !isFinishing, sampleBuffer.isValid,
      Self.isCompleteFrame(sampleBuffer)
    else { return }
    writer.appendVideo(sampleBuffer)
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    DispatchQueue.main.async { self.onStreamStopped?(error) }
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
