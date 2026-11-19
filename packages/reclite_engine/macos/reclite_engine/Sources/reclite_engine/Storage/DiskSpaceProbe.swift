import Foundation

enum DiskSpaceProbe {
  /// Free/total bytes of the volume containing `path`.
  ///
  /// Uses "available for important usage", which counts purgeable space macOS
  /// will free on demand — the same number Finder shows.
  static func query(path: String) throws -> DiskSpace {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw PigeonError(code: "invalid_path", message: "Path does not exist: \(path)", details: nil)
    }

    do {
      let values = try url.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeAvailableCapacityKey,
        .volumeTotalCapacityKey,
      ])
      let important = values.volumeAvailableCapacityForImportantUsage ?? 0
      let free = important > 0 ? important : Int64(values.volumeAvailableCapacity ?? 0)
      return DiskSpace(freeBytes: free, totalBytes: Int64(values.volumeTotalCapacity ?? 0))
    } catch {
      throw PigeonError(code: "disk_query_failed", message: error.localizedDescription, details: nil)
    }
  }
}
