import Foundation

/// File names, identical to Windows. Videos go straight into the save folder:
///   RecLite_2026-11-19_10-00-00.mp4                    (one part)
///   RecLite_2026-11-19_10-00-00_Part01.mp4, _Part02…   (long recordings)
/// The manifest lives in `sessionsDirectory()` as RecLite_2026-11-19_10-00-00.json.
enum SessionNaming {
  static let prefix = "RecLite"

  private static let stampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter
  }()

  static func stamp(_ date: Date) -> String { stampFormatter.string(from: date) }

  /// ~/Library/Application Support/RecLite/Sessions, created if needed.
  static func sessionsDirectory() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let sessions = support.appendingPathComponent("RecLite/Sessions", isDirectory: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    return sessions
  }

  /// `RecLite_<stamp>`, or `_2`, `_3`… when a recording with that name already exists
  /// in `folder` or `sessions`, so nothing is ever overwritten.
  static func uniqueBaseName(in folder: URL, sessions: URL, startedAt date: Date) -> String {
    let fileManager = FileManager.default
    let first = "\(prefix)_\(stamp(date))"
    for n in 1...999 {
      let base = n == 1 ? first : "\(first)_\(n)"
      let taken = [
        folder.appendingPathComponent("\(base).mp4"),
        folder.appendingPathComponent("\(base)_Part01.mp4"),
        folder.appendingPathComponent("\(base)_Part01.mp4.part"),
        sessions.appendingPathComponent("\(base).json"),
      ].contains { fileManager.fileExists(atPath: $0.path) }
      if !taken { return base }
    }
    return "\(first)_\(UUID().uuidString.prefix(8))"
  }

  static func segmentFileName(base: String, index: Int) -> String {
    String(format: "%@_Part%02d.mp4", base, index)
  }

  /// A recording that ended as a single part is renamed `<base>.mp4` (no `_Part01`);
  /// updates the manifest. Returns the video's URL either way.
  @discardableResult
  static func tidySinglePart(_ manifest: inout SessionManifest) -> URL? {
    guard let directory = manifest.directory, let only = manifest.segments.first else {
      return nil
    }
    let folder = URL(fileURLWithPath: directory, isDirectory: true)
    let current = folder.appendingPathComponent(only.file)
    guard manifest.segments.count == 1, only.file.hasSuffix("_Part01.mp4") else { return current }
    let single = folder.appendingPathComponent(
      String(only.file.dropLast("_Part01.mp4".count)) + ".mp4")
    guard !FileManager.default.fileExists(atPath: single.path),
      (try? FileManager.default.moveItem(at: current, to: single)) != nil
    else { return current }
    manifest.segments[0].file = single.lastPathComponent
    return single
  }
}
