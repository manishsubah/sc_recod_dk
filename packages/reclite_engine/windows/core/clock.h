#ifndef RECLITE_ENGINE_CORE_CLOCK_H_
#define RECLITE_ENGINE_CORE_CLOCK_H_

#include <cstdint>

#include "ticks.h"
#include "win.h"

namespace reclite_engine {

// QPC ticks: the clock Windows Graphics Capture frames and WASAPI packets use.
inline int64_t HostNow() {
  static const int64_t frequency = [] {
    LARGE_INTEGER f;
    ::QueryPerformanceFrequency(&f);
    return f.QuadPart;
  }();
  LARGE_INTEGER counter;
  ::QueryPerformanceCounter(&counter);
  const int64_t whole = counter.QuadPart / frequency;
  const int64_t rest = counter.QuadPart % frequency;
  return whole * kTicksPerSecond + rest * kTicksPerSecond / frequency;
}

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_CLOCK_H_
