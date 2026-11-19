#include "platform_dispatcher.h"

#include <utility>

namespace reclite_engine {
namespace {

constexpr wchar_t kWindowClass[] = L"RecLiteEngineDispatcher";
constexpr UINT kRunTasks = WM_APP + 0x52;

}  // namespace

PlatformDispatcher::PlatformDispatcher() {
  const HINSTANCE instance = ::GetModuleHandleW(nullptr);
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = &PlatformDispatcher::WindowProc;
  window_class.hInstance = instance;
  window_class.lpszClassName = kWindowClass;
  ::RegisterClassExW(&window_class);  // Fails harmlessly if already registered.

  window_ = ::CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, instance, nullptr);
  if (window_ != nullptr) {
    ::SetWindowLongPtrW(window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }
}

PlatformDispatcher::~PlatformDispatcher() {
  if (window_ != nullptr) {
    for (const auto& timer : timers_) {
      ::KillTimer(window_, timer.first);
    }
    ::SetWindowLongPtrW(window_, GWLP_USERDATA, 0);
    ::DestroyWindow(window_);
  }
}

void PlatformDispatcher::Post(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks_.push_back(std::move(task));
  }
  if (window_ != nullptr) {
    ::PostMessageW(window_, kRunTasks, 0, 0);
  }
}

void PlatformDispatcher::StartTimer(UINT_PTR id, UINT interval_ms,
                                    std::function<void()> tick) {
  timers_[id] = std::move(tick);
  if (window_ != nullptr) {
    ::SetTimer(window_, id, interval_ms, nullptr);
  }
}

void PlatformDispatcher::StopTimer(UINT_PTR id) {
  if (window_ != nullptr) {
    ::KillTimer(window_, id);
  }
  timers_.erase(id);
}

void PlatformDispatcher::Drain() {
  std::deque<std::function<void()>> batch;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    batch.swap(tasks_);
  }
  for (auto& task : batch) {
    task();
  }
}

LRESULT CALLBACK PlatformDispatcher::WindowProc(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam) {
  auto* self =
      reinterpret_cast<PlatformDispatcher*>(::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (self != nullptr) {
    if (message == kRunTasks) {
      self->Drain();
      return 0;
    }
    if (message == WM_TIMER) {
      const auto timer = self->timers_.find(static_cast<UINT_PTR>(wparam));
      if (timer != self->timers_.end()) {
        auto tick = timer->second;  // The tick may stop its own timer.
        tick();
      }
      return 0;
    }
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace reclite_engine
