#ifndef RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_
#define RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "session_manifest.h"

namespace reclite_engine {

// File names, identical to macOS. Videos go straight into the save folder:
//   RecLite_2026-11-19_10-00-00.mp4                    (one part)
//   RecLite_2026-11-19_10-00-00_Part01.mp4, _Part02…   (long recordings)
// The metadata lives in SessionsDirectory() as RecLite_2026-11-19_10-00-00.json.
namespace session_naming {

// Local time, `seconds_from_now` ahead, as yyyy-MM-dd_HH-mm-ss.
std::wstring Stamp(double seconds_from_now = 0);

// "RecLite_<stamp>", or "RecLite_<stamp>_2", _3… when a recording with that name
// already exists in `folder` or `sessions`, so nothing is ever overwritten.
std::wstring UniqueBaseName(const std::filesystem::path& folder,
                            const std::filesystem::path& sessions, const std::wstring& stamp);

std::wstring SegmentFileName(const std::wstring& base, int index);

// Current UTC time as ISO 8601, e.g. 2026-11-19T04:30:00Z.
std::string UtcNow();

}  // namespace session_naming

// %LOCALAPPDATA%\RecLite\Sessions, created if needed. Empty if unavailable.
std::filesystem::path SessionsDirectory();

// Atomic: a crash mid-write leaves the previous manifest intact.
bool WriteManifest(const SessionManifest& manifest, const std::filesystem::path& file);
std::optional<SessionManifest> ReadManifest(const std::filesystem::path& file);

// A recording that ended as a single part is renamed RecLite_<stamp>.mp4 (no
// "_Part01"); updates the manifest. Returns the video's path either way.
std::filesystem::path TidySinglePart(SessionManifest* manifest);

struct RecoveredSession {
  std::filesystem::path directory;
  std::vector<std::filesystem::path> files;
  int64_t duration_ms = 0;
};

// Repairs recordings cut off by a crash, power loss or force quit (manifests in
// `sessions` still marked "recording"), skipping the `active` manifest.
// Playable .mp4.part files become .mp4; empty ones are deleted; unreadable ones are
// kept as .unplayable so no data is ever silently thrown away.
// Needs COM + Media Foundation started on the calling thread.
std::vector<RecoveredSession> RecoverSessions(const std::filesystem::path& sessions,
                                              const std::filesystem::path& active);

// Seconds of video in an MP4 (also fragmented/unfinished ones); empty if unreadable.
std::optional<double> PlayableSeconds(const std::filesystem::path& file);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_STORAGE_SESSION_STORAGE_H_
