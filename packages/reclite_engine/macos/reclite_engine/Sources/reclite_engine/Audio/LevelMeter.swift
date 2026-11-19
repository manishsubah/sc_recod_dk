import Foundation

/// Peak level per source, written on the capture queue and read (and reset) by the UI timer.
final class LevelMeter: @unchecked Sendable {
  private let lock = NSLock()
  private var peaks: [Float]

  init(sourceCount: Int) {
    peaks = Array(repeating: 0, count: sourceCount)
  }

  func record(source: Int, samples: [Float]) {
    var peak: Float = 0
    for sample in samples {
      peak = max(peak, abs(sample))
    }
    lock.lock()
    peaks[source] = max(peaks[source], peak)
    lock.unlock()
  }

  /// Peaks since the last call, mapped to 0…1 on a -60…0 dBFS scale.
  func takeLevels() -> [Double] {
    lock.lock()
    let current = peaks
    peaks = Array(repeating: 0, count: peaks.count)
    lock.unlock()
    return current.map { peak in
      guard peak > 0 else { return 0 }
      let db = 20 * log10(Double(peak))
      return min(1, max(0, (db + 60) / 60))
    }
  }
}
