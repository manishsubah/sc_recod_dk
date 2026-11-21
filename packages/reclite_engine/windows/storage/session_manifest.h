#ifndef RECLITE_ENGINE_STORAGE_SESSION_MANIFEST_H_
#define RECLITE_ENGINE_STORAGE_SESSION_MANIFEST_H_

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace reclite_engine {

// The recording's metadata — same fields as the macOS manifest (docs/PLAN.md
// §16.2), so History can read recordings from either platform. Kept in the app's
// own data folder, not next to the videos. Strings are UTF-8.
// Platform-independent (unit-tested on any OS); file I/O is in session_storage.
struct SessionManifest {
  struct Segment {
    int index = 0;
    std::string file;
    int64_t duration_ms = 0;
    int64_t bytes = 0;
    std::string status = "complete";  // or "recovered"
  };

  std::string session_id;
  // Folder holding the videos (the user's save folder). Empty in old manifests,
  // which sat inside a per-recording folder next to their videos.
  std::string directory;
  std::string started_at;  // ISO 8601, UTC
  std::string ended_at;
  std::string status = "recording";  // recording | completed | recovered | failed
  std::string source_type = "display";
  std::string source_name;
  std::vector<double> area;  // x, y, width, height when recording an area
  bool system_audio = false;
  bool microphone = false;
  int width = 0;
  int height = 0;
  int fps = 0;
  int segment_seconds = 0;
  std::vector<Segment> segments;

  int64_t TotalDurationMs() const;
  // Keeps segments sorted; ignores an index that is already listed.
  void AddSegment(const Segment& segment);

  std::string ToJson() const;
  static std::optional<SessionManifest> FromJson(const std::string& json);
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_STORAGE_SESSION_MANIFEST_H_
