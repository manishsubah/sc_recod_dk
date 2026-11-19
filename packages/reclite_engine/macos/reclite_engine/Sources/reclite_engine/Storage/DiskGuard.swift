import Foundation

/// Free-space policy while recording (docs/PLAN.md §16).
enum DiskGuard {
  enum Verdict: Equatable {
    case ok, low, critical
  }

  static let checkEverySeconds = 10
  static let warnBelowBytes: Int64 = 2_000_000_000
  /// Stop with room to spare so the open part can still be finalized.
  static let stopBelowBytes: Int64 = 500_000_000

  static func verdict(freeBytes: Int64) -> Verdict {
    if freeBytes < stopBelowBytes { return .critical }
    if freeBytes < warnBelowBytes { return .low }
    return .ok
  }

  static func lowSpaceMessage(freeBytes: Int64, bytesPerSecond: Double) -> String {
    let free = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    let usable = Double(freeBytes - stopBelowBytes)
    guard bytesPerSecond > 0, usable > 0 else {
      return "Low disk space: \(free) left. Recording stops before the disk is full."
    }
    let minutes = Int(usable / bytesPerSecond / 60)
    return
      "Low disk space: \(free) left (about \(max(minutes, 1)) min of recording). "
      + "Recording stops safely before the disk is full."
  }
}
