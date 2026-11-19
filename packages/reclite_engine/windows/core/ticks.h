#ifndef RECLITE_ENGINE_CORE_TICKS_H_
#define RECLITE_ENGINE_CORE_TICKS_H_

#include <cstdint>

namespace reclite_engine {

// Engine time unit: 100-nanosecond ticks (QPC clock, see clock.h). Kept free of
// <windows.h> so the audio code can be unit-tested on any platform.
constexpr int64_t kTicksPerSecond = 10'000'000;
constexpr int64_t kTicksPerMillisecond = 10'000;

inline double TicksToSeconds(int64_t ticks) {
  return static_cast<double>(ticks) / static_cast<double>(kTicksPerSecond);
}

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_TICKS_H_
