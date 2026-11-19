import Foundation

enum SessionNaming {
  static let prefix = "RecLite"

  private static let stampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter
  }()

  static func stamp(_ date: Date) -> String { stampFormatter.string(from: date) }

  /// Creates `<parent>/RecLite_<stamp>`; adds `_2`, `_3`… so an existing folder is never reused.
  static func createSessionDirectory(in parent: URL, startedAt date: Date) throws -> URL {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

    let base = "\(prefix)_\(stamp(date))"
    for attempt in 1...999 {
      let name = attempt == 1 ? base : "\(base)_\(attempt)"
      let candidate = parent.appendingPathComponent(name, isDirectory: true)
      do {
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: false)
        return candidate
      } catch let error as CocoaError where error.code == .fileWriteFileExists {
        continue
      }
    }
    throw CocoaError(.fileWriteFileExists)
  }

  static func segmentFileName(startedAt date: Date, index: Int) -> String {
    String(format: "%@_%@_Part%02d.mp4", prefix, stamp(date), index)
  }
}
