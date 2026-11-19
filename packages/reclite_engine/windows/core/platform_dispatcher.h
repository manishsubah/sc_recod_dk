#ifndef RECLITE_ENGINE_CORE_PLATFORM_DISPATCHER_H_
#define RECLITE_ENGINE_CORE_PLATFORM_DISPATCHER_H_

#include <deque>
#include <functional>
#include <map>
#include <mutex>

#include "win.h"

namespace reclite_engine {

// Runs work on the Flutter platform thread (where Pigeon replies and events must
// be sent) via a hidden message-only window pumped by the runner's message loop.
// Create and destroy on the platform thread.
class PlatformDispatcher {
 public:
  PlatformDispatcher();
  ~PlatformDispatcher();

  PlatformDispatcher(const PlatformDispatcher&) = delete;
  PlatformDispatcher& operator=(const PlatformDispatcher&) = delete;

  // Safe from any thread.
  void Post(std::function<void()> task);

  // Repeating timer on the platform thread. Re-using an id replaces the timer.
  void StartTimer(UINT_PTR id, UINT interval_ms, std::function<void()> tick);
  void StopTimer(UINT_PTR id);

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  void Drain();

  HWND window_ = nullptr;
  std::mutex mutex_;
  std::deque<std::function<void()>> tasks_;
  std::map<UINT_PTR, std::function<void()>> timers_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_PLATFORM_DISPATCHER_H_
