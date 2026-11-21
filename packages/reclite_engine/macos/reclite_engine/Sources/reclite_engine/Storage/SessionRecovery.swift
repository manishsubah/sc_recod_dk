import AVFoundation

/// Repairs recordings that were cut off by a crash, power loss or force quit.
enum SessionRecovery {
  struct Recovered {
    let directory: URL
    let files: [URL]
    let durationMs: Int64
  }

  /// Unfinished parts shorter than this are noise (a part opened just before the crash).
  static let minimumPlayableSeconds = 0.25

  /// Repairs recordings whose manifest in `sessions` is still marked recording,
  /// skipping the `active` manifest. Playable `.mp4.part` files become `.mp4`; empty
  /// ones are deleted; unreadable ones are kept as `.unplayable` so no data is ever
  /// thrown away silently.
  static func recover(sessions: URL, skipping active: URL?) async -> [Recovered] {
    let manifests = ((try? FileManager.default.contentsOfDirectory(
      at: sessions, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var results: [Recovered] = []
    for file in manifests where file.standardizedFileURL != active?.standardizedFileURL {
      if let recovered = await recoverSession(manifestFile: file) {
        results.append(recovered)
      }
    }
    return results
  }

  private static func recoverSession(manifestFile: URL) async -> Recovered? {
    guard var manifest = SessionManifest.read(from: manifestFile),
      manifest.status == .recording, let folder = manifest.directory
    else { return nil }
    let fileManager = FileManager.default
    let directory = URL(fileURLWithPath: folder, isDirectory: true)
    let partsPrefix = manifestFile.deletingPathExtension().lastPathComponent + "_Part"
    let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
    let partials = names.filter { $0.hasPrefix(partsPrefix) && $0.hasSuffix(".mp4.part") }
      .sorted()

    for name in partials {
      let partial = directory.appendingPathComponent(name)
      let size = (try? fileManager.attributesOfItem(atPath: partial.path)[.size] as? NSNumber)?
        .int64Value ?? 0
      guard size > 0 else {
        try? fileManager.removeItem(at: partial)
        continue
      }
      let target = uniqueURL(for: partial.deletingPathExtension())
      do {
        try fileManager.moveItem(at: partial, to: target)
      } catch {
        continue
      }
      guard let seconds = await playableSeconds(of: target), seconds >= minimumPlayableSeconds
      else {
        try? fileManager.moveItem(at: target, to: uniqueURL(for: partial.appendingPathExtension("unplayable")))
        continue
      }
      let index = partIndex(in: target.lastPathComponent) ?? manifest.segments.count + 1
      manifest.segments.append(
        SessionManifest.Segment(
          index: index,
          file: target.lastPathComponent,
          durationMs: Int64(seconds * 1000),
          bytes: size,
          status: "recovered"))
    }

    manifest.segments.sort { $0.index < $1.index }
    manifest.status = .recovered
    SessionNaming.tidySinglePart(&manifest)
    let files = manifest.segments
      .map { directory.appendingPathComponent($0.file) }
      .filter { fileManager.fileExists(atPath: $0.path) }
    manifest.endedAt = manifest.endedAt ?? lastModified(files) ?? Date()
    try? manifest.write(to: manifestFile)
    guard !files.isEmpty else { return nil }
    return Recovered(directory: directory, files: files, durationMs: manifest.totalDurationMs)
  }

  static func playableSeconds(of url: URL) async -> Double? {
    let asset = AVURLAsset(url: url)
    guard let duration = try? await asset.load(.duration), duration.isNumeric else { return nil }
    let tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
    return tracks.isEmpty ? nil : CMTimeGetSeconds(duration)
  }

  /// `RecLite_…_Part03.mp4` → 3.
  private static func partIndex(in fileName: String) -> Int? {
    guard let range = fileName.range(of: "_Part", options: .backwards) else { return nil }
    return Int(fileName[range.upperBound...].prefix { $0.isNumber })
  }

  private static func uniqueURL(for url: URL) -> URL {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else { return url }
    let base = url.deletingPathExtension().path
    let ext = url.pathExtension
    for n in 2...999 {
      let candidate = URL(fileURLWithPath: "\(base)_\(n)").appendingPathExtension(ext)
      if !fileManager.fileExists(atPath: candidate.path) { return candidate }
    }
    return url
  }

  private static func lastModified(_ files: [URL]) -> Date? {
    files.compactMap {
      try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }.max()
  }
}
