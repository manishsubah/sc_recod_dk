#include "disk_space_probe.h"

#include <windows.h>

namespace reclite_engine {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
      static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), wide.data(), length);
  return wide;
}

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
