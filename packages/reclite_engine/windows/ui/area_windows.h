#ifndef RECLITE_ENGINE_UI_AREA_WINDOWS_H_
#define RECLITE_ENGINE_UI_AREA_WINDOWS_H_

#include <functional>
#include <optional>

#include "../core/win.h"

namespace reclite_engine {

// Full-screen overlay on one monitor where the user drags out the area to record.
// Platform thread only. Excluded from capture.
class AreaSelector {
 public:
  static constexpr int kMinimumSize = 64;

  // `done` gets the rect in physical pixels relative to the monitor's top-left,
  // or nothing when the user pressed Esc / right-clicked.
  using Done = std::function<void(std::optional<RECT>)>;

  ~AreaSelector();
  void Select(HMONITOR monitor, Done done);

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  LRESULT Handle(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  RECT Selection() const;
  void Paint(HWND hwnd);
  void Finish(std::optional<RECT> result);

  HWND window_ = nullptr;
  Done done_;
  bool dragging_ = false;
  bool has_selection_ = false;
  POINT start_{};
  POINT current_{};
};

// Red outline around the recorded area. Click-through and excluded from capture.
class AreaHighlight {
 public:
  ~AreaHighlight();
  // `area` is in physical pixels relative to the monitor's top-left.
  void Show(HMONITOR monitor, RECT area);
  void Hide();

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  HWND window_ = nullptr;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_UI_AREA_WINDOWS_H_
