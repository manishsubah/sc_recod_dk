#ifndef RECLITE_ENGINE_CORE_SERIAL_QUEUE_H_
#define RECLITE_ENGINE_CORE_SERIAL_QUEUE_H_

#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>

namespace reclite_engine {

// One worker thread running tasks in order — the Windows twin of the macOS
// capture queue. Recorder state is only touched here.
class SerialQueue {
 public:
  // `thread_init`/`thread_exit` run on the worker (e.g. COM + Media Foundation setup).
  SerialQueue(std::function<void()> thread_init, std::function<void()> thread_exit);
  ~SerialQueue();

  SerialQueue(const SerialQueue&) = delete;
  SerialQueue& operator=(const SerialQueue&) = delete;

  void Post(std::function<void()> task);

  // Runs `tick` about every `interval`, ahead of queued tasks when it is due.
  void SetTicker(std::chrono::milliseconds interval, std::function<void()> tick);
  void ClearTicker();

 private:
  void Run();

  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<std::function<void()>> tasks_;
  std::function<void()> tick_;
  std::chrono::milliseconds interval_{0};
  std::chrono::steady_clock::time_point next_tick_;
  bool stopping_ = false;
  std::function<void()> init_;
  std::function<void()> exit_;
  std::thread thread_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_SERIAL_QUEUE_H_
