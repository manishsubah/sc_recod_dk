import Foundation

/// `session.json` in each recording folder: what was recorded and which parts exist.
/// History reads it; crash recovery repairs it. See docs/PLAN.md §16.2.
struct SessionManifest: Codable, Equatable {
  enum Status: String, Codable {
    case recording, completed, recovered, failed
  }

  struct Segment: Codable, Equatable {
    var index: Int
    var file: String
    var durationMs: Int64
    var bytes: Int64
    /// `complete`, or `recovered` when repaired after a crash.
    var status: String
  }

  struct Source: Codable, Equatable {
    var type: String
    var name: String
    /// `[x, y, width, height]` in points when recording an area.
    var area: [Double]?
  }

  struct Audio: Codable, Equatable {
    var system: Bool
    var microphone: Bool
  }

  struct Video: Codable, Equatable {
    var codec: String
    var width: Int
    var height: Int
    var fps: Int
  }

  static let fileName = "session.json"

  var app = "RecLite"
  var version = 1
  var sessionId: String
  var startedAt: Date
  var endedAt: Date?
  var status: Status
  var source: Source
  var audio: Audio
  var video: Video
  var segmentSeconds: Int
  var segments: [Segment]

  var totalDurationMs: Int64 { segments.reduce(0) { $0 + $1.durationMs } }

  /// Atomic: a crash mid-write leaves the previous version intact.
  func write(to directory: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(self).write(
      to: directory.appendingPathComponent(Self.fileName), options: .atomic)
  }

  static func read(from directory: URL) -> SessionManifest? {
    guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(SessionManifest.self, from: data)
  }
}
