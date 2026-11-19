#ifndef RECLITE_ENGINE_STORAGE_DISK_GUARD_H_
#define RECLITE_ENGINE_STORAGE_DISK_GUARD_H_

#include <cstdint>
#include <string>

namespace reclite_engine {
namespace disk_guard {

// Free-space policy while recording (docs/PLAN.md §16) — same values as macOS.
enum class Verdict { kOk, kLow, kCritical };

constexpr int kCheckEverySeconds = 10;
constexpr int64_t kWarnBelowBytes = 2'000'000'000;
// Stop with room to spare so the open part can still be finalized.
constexpr int64_t kStopBelowBytes = 500'000'000;

Verdict Check(int64_t free_bytes);
std::string LowSpaceMessage(int64_t free_bytes, double bytes_per_second);

}  // namespace disk_guard
}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_STORAGE_DISK_GUARD_H_
