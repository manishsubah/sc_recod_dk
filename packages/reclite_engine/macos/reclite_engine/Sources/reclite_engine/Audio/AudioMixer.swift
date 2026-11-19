import Foundation

/// Mixes stereo Float32 streams placed on one shared frame timeline (48 kHz).
///
/// Each source pushes frames at the timeline position of their timestamp. Gaps
/// become silence, overlaps are trimmed, and audio older than what was already
/// emitted is dropped, so a late or silent source never stalls the output.
/// Not thread-safe: use from one serial queue.
final class AudioMixer {
  static let channels = 2

  /// Bounds the silence inserted for one gap, so a bad timestamp can't allocate minutes of zeros.
  static let maxGapFrames: Int64 = 48_000 * 5

  private var queues: [[Float]]
  private var heads: [Int]
  private var starts: [Int64]
  private let gains: [Float]

  private(set) var outputFrame: Int64 = 0

  init(sourceCount: Int, gains: [Float]? = nil) {
    queues = Array(repeating: [], count: sourceCount)
    heads = Array(repeating: 0, count: sourceCount)
    starts = Array(repeating: 0, count: sourceCount)
    self.gains = gains ?? Array(repeating: 1, count: sourceCount)
  }

  /// Timeline frame just past the last buffered sample, or nil when the source has nothing queued.
  func endFrame(of source: Int) -> Int64? {
    let count = bufferedFrames(source)
    return count == 0 ? nil : starts[source] + Int64(count)
  }

  /// `samples` are interleaved stereo; `startFrame` is the timeline position of the first one.
  func push(source: Int, samples: [Float], startFrame: Int64) {
    var frameCount = samples.count / Self.channels
    guard frameCount > 0 else { return }
    var first = 0
    var start = startFrame

    if start < outputFrame {
      let late = Int(outputFrame - start)
      guard late < frameCount else { return }
      first += late
      frameCount -= late
      start = outputFrame
    }

    if bufferedFrames(source) == 0 {
      queues[source].removeAll(keepingCapacity: true)
      heads[source] = 0
      starts[source] = start
    } else {
      let end = starts[source] + Int64(bufferedFrames(source))
      if start > end {
        let gap = Int(min(start - end, Self.maxGapFrames))
        queues[source].append(contentsOf: repeatElement(0, count: gap * Self.channels))
      } else if start < end {
        let overlap = Int(end - start)
        guard overlap < frameCount else { return }
        first += overlap
        frameCount -= overlap
      }
    }

    let from = first * Self.channels
    queues[source].append(contentsOf: samples[from..<(from + frameCount * Self.channels)])
  }

  /// Mixes and consumes frames `[outputFrame, frame)`. Missing samples are silence.
  func pull(until frame: Int64) -> [Float] {
    guard frame > outputFrame else { return [] }
    let count = Int(frame - outputFrame)
    var out = [Float](repeating: 0, count: count * Self.channels)

    for source in queues.indices {
      let available = bufferedFrames(source)
      guard available > 0 else { continue }
      // The queue may start before the window (already partly consumed) or inside it (late start).
      let into = Int(max(0, starts[source] - outputFrame))
      let skip = Int(max(0, outputFrame - starts[source]))
      let usable = max(0, min(count - into, available - skip))
      if usable > 0 {
        let gain = gains[source]
        queues[source].withUnsafeBufferPointer { queue in
          let src = heads[source] + skip * Self.channels
          let dst = into * Self.channels
          for i in 0..<(usable * Self.channels) {
            out[dst + i] += queue[src + i] * gain
          }
        }
      }
      let beforeEnd = Int(max(0, frame - starts[source]))
      consume(source: source, frames: min(available, beforeEnd))
    }

    for i in out.indices {
      out[i] = min(1, max(-1, out[i]))
    }
    outputFrame = frame
    return out
  }

  private func bufferedFrames(_ source: Int) -> Int {
    (queues[source].count - heads[source]) / Self.channels
  }

  private func consume(source: Int, frames: Int) {
    heads[source] += frames * Self.channels
    starts[source] += Int64(frames)
    if heads[source] >= 48_000 * Self.channels {
      queues[source].removeFirst(heads[source])
      heads[source] = 0
    }
  }
}
