#include "serial_queue.h"

#include <utility>

namespace reclite_engine {

SerialQueue::SerialQueue(std::function<void()> thread_init,
                         std::function<void()> thread_exit)
    : init_(std::move(thread_init)), exit_(std::move(thread_exit)) {
  thread_ = std::thread([this] { Run(); });
}

SerialQueue::~SerialQueue() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stopping_ = true;
  }
  wake_.notify_all();
  if (thread_.joinable()) {
    thread_.join();
  }
}

void SerialQueue::Post(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stopping_) {
      return;
    }
    tasks_.push_back(std::move(task));
  }
  wake_.notify_one();
}

void SerialQueue::SetTicker(std::chrono::milliseconds interval,
                            std::function<void()> tick) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    interval_ = interval;
    tick_ = std::move(tick);
    next_tick_ = std::chrono::steady_clock::now() + interval;
  }
  wake_.notify_one();
}

void SerialQueue::ClearTicker() {
  std::lock_guard<std::mutex> lock(mutex_);
  tick_ = nullptr;
}

void SerialQueue::Run() {
  if (init_) {
    init_();
  }
  for (;;) {
    std::function<void()> work;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      const auto ready = [this] {
        return stopping_ || !tasks_.empty() ||
               (tick_ && std::chrono::steady_clock::now() >= next_tick_);
      };
      if (tick_) {
        wake_.wait_until(lock, next_tick_, ready);
      } else {
        wake_.wait(lock, ready);
      }
      if (stopping_) {
        break;
      }
      const auto now = std::chrono::steady_clock::now();
      if (tick_ && now >= next_tick_) {
        work = tick_;
        next_tick_ = now + interval_;
      } else if (!tasks_.empty()) {
        work = std::move(tasks_.front());
        tasks_.pop_front();
      }
    }
    if (work) {
      work();
    }
  }
  tasks_.clear();
  if (exit_) {
    exit_();
  }
}

}  // namespace reclite_engine
