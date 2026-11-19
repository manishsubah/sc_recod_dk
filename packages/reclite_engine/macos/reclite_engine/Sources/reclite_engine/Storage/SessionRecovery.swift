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

  /// Scans `parent` for `RecLite_*` folders left mid-recording, skipping `active`.
  /// Playable `.mp4.part` files become `.mp4`; empty ones are deleted; unreadable ones
  /// are kept as `.unplayable` so no data is ever thrown away silently.
  static func recover(in parent: URL, skipping active: URL?) async -> [Recovered] {
    let fileManager = FileManager.default
    guard
      let entries = try? fileManager.contentsOfDirectory(
        at: parent, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
    else { return [] }

    var results: [Recovered] = []
    for directory in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    where directory.lastPathComponent.hasPrefix(SessionNaming.prefix + "_") {
      guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
        directory.standardizedFileURL != active?.standardizedFileURL
      else { continue }
      if let recovered = await recoverSession(at: directory) {
        results.append(recovered)
      }
    }
    return results
  }

  private static func recoverSession(at directory: URL) async -> Recovered? {
    let fileManager = FileManager.default
    let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
    let partials = names.filter { $0.hasSuffix(".mp4.part") }.sorted()
    var manifest = SessionManifest.read(from: directory)
    guard !partials.isEmpty || manifest?.status == .recording else { return nil }

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
      let index =
        partIndex(in: target.lastPathComponent) ?? (manifest?.segments.count ?? 0) + 1
      manifest?.segments.append(
        SessionManifest.Segment(
          index: index,
          file: target.lastPathComponent,
          durationMs: Int64(seconds * 1000),
          bytes: size,
          status: "recovered"))
    }

    let files = ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
      .filter { $0.hasSuffix(".mp4") }
      .sorted()
      .map { directory.appendingPathComponent($0) }

    if var repaired = manifest {
      repaired.segments.sort { $0.index < $1.index }
      repaired.status = .recovered
      repaired.endedAt = repaired.endedAt ?? lastModified(files) ?? Date()
      try? repaired.write(to: directory)
      manifest = repaired
    }
    guard !files.isEmpty else { return nil }

    var durationMs = manifest?.totalDurationMs ?? 0
    if manifest == nil {
      for file in files {
        durationMs += Int64((await playableSeconds(of: file) ?? 0) * 1000)
      }
    }
    return Recovered(directory: directory, files: files, durationMs: durationMs)
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
