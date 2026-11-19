#include "disk_space_probe.h"

#include <windows.h>

namespace reclite_engine {

ErrorOr<DiskSpace> QueryDiskSpace(const std::string& utf8_path) {
  const std::wstring path = Utf8ToWide(utf8_path);
  if (path.empty() ||
      ::GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return FlutterError("invalid_path", "Path does not exist: " + utf8_path);
  }

  ULARGE_INTEGER free_to_caller{};
  ULARGE_INTEGER total{};
  if (!::GetDiskFreeSpaceExW(path.c_str(), &free_to_caller, &total, nullptr)) {
    return FlutterError("disk_query_failed",
                        "GetDiskFreeSpaceExW failed, error " +
                            std::to_string(::GetLastError()));
  }
  return DiskSpace(static_cast<int64_t>(free_to_caller.QuadPart),
                   static_cast<int64_t>(total.QuadPart));
}

}  // namespace reclite_engine
