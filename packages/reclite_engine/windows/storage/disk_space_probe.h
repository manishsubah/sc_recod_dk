#ifndef RECLITE_ENGINE_DISK_SPACE_PROBE_H_
#define RECLITE_ENGINE_DISK_SPACE_PROBE_H_

#include <string>

#include "../messages.g.h"

namespace reclite_engine {

// Free/total bytes of the volume containing `utf8_path`.
// Returns FlutterError("invalid_path") if the path does not exist.
ErrorOr<DiskSpace> QueryDiskSpace(const std::string& utf8_path);

// UTF-8 (Dart strings) -> UTF-16 (Win32 APIs).
std::wstring Utf8ToWide(const std::string& utf8);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_DISK_SPACE_PROBE_H_
