#ifndef RECLITE_ENGINE_DISK_SPACE_PROBE_H_
#define RECLITE_ENGINE_DISK_SPACE_PROBE_H_

#include <string>

#include "../core/strings.h"
#include "../messages.g.h"

namespace reclite_engine {

// Free/total bytes of the volume containing `utf8_path`.
// Returns FlutterError("invalid_path") if the path does not exist.
ErrorOr<DiskSpace> QueryDiskSpace(const std::string& utf8_path);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_DISK_SPACE_PROBE_H_
