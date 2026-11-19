#ifndef RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_
#define RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "session_manifest.h"

namespace reclite_engine {

// Folder and file names, identical to macOS:
//   RecLite_2026-11-19_10-00-00/RecLite_2026-11-19_10-15-00_Part02.mp4
namespace session_naming {

// Local time, `seconds_from_now` ahead, as yyyy-MM-dd_HH-mm-ss.
std::wstring Stamp(double seconds_from_now = 0);

// Creates <parent>/RecLite_<stamp>, adding _2, _3… so an existing folder is never reused.
std::optional<std::filesystem::path> CreateSessionDirectory(
    const std::filesystem::path& parent, const std::wstring& stamp, std::string* error);

std::wstring SegmentFileName(const std::wstring& stamp, int index);

// Current UTC time as ISO 8601, e.g. 2026-11-19T04:30:00Z.
std::string UtcNow();

}  // namespace session_naming

// Atomic: a crash mid-write leaves the previous session.json intact.
bool WriteManifest(const SessionManifest& manifest, const std::filesystem::path& directory);
std::optional<SessionManifest> ReadManifest(const std::filesystem::path& directory);

struct RecoveredSession {
  std::filesystem::path directory;
  std::vector<std::filesystem::path> files;
  int64_t duration_ms = 0;
};

// Repairs recordings cut off by a crash, power loss or force quit, skipping `active`.
// Playable .mp4.part files become .mp4; empty ones are deleted; unreadable ones are
// kept as .unplayable so no data is ever silently thrown away.
// Needs COM + Media Foundation started on the calling thread.
std::vector<RecoveredSession> RecoverSessions(const std::filesystem::path& parent,
                                              const std::filesystem::path& active);

// Seconds of video in an MP4 (also fragmented/unfinished ones); empty if unreadable.
std::optional<double> PlayableSeconds(const std::filesystem::path& file);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_
