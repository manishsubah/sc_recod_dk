#include "disk_guard.h"

#include <algorithm>
#include <cstdio>

namespace reclite_engine {
namespace disk_guard {

Verdict Check(int64_t free_bytes) {
  if (free_bytes < kStopBelowBytes) return Verdict::kCritical;
  if (free_bytes < kWarnBelowBytes) return Verdict::kLow;
  return Verdict::kOk;
}

std::string LowSpaceMessage(int64_t free_bytes, double bytes_per_second) {
  char free_text[32];
  std::snprintf(free_text, sizeof(free_text), "%.1f GB",
                static_cast<double>(free_bytes) / 1e9);
  const double usable = static_cast<double>(free_bytes - kStopBelowBytes);
  if (bytes_per_second <= 0 || usable <= 0) {
    return std::string("Low disk space: ") + free_text +
           " left. Recording stops before the disk is full.";
  }
  const int minutes = std::max(1, static_cast<int>(usable / bytes_per_second / 60));
  return std::string("Low disk space: ") + free_text + " left (about " +
         std::to_string(minutes) +
         " min of recording). Recording stops safely before the disk is full.";
}

}  // namespace disk_guard
}  // namespace reclite_engine
