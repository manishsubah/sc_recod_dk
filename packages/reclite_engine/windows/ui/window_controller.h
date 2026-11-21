#ifndef RECLITE_ENGINE_UI_WINDOW_CONTROLLER_H_
#define RECLITE_ENGINE_UI_WINDOW_CONTROLLER_H_

#include <flutter/plugin_registrar_windows.h>

#include <optional>

#include "../core/win.h"

namespace reclite_engine {

// Turns RecLite's main window into a small always-on-top bar and back. The
// runner's 760x560 minimum size is lifted while the bar is shown. Platform thread.
class WindowController {
 public:
  explicit WindowController(flutter::PluginRegistrarWindows* registrar);
  ~WindowController();

  WindowController(const WindowController&) = delete;
  WindowController& operator=(const WindowController&) = delete;

  void SetMini(bool mini);

  // Moves the window with the mouse; the left button must be down.
  void StartDrag();

  // Restores a minimized or hidden window and brings it to the front.
  void BringToFront();

 private:
  HWND Root() const;
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

  flutter::PluginRegistrarWindows* registrar_;
  int delegate_id_ = 0;
  bool mini_ = false;
  WINDOWPLACEMENT saved_placement_{};
  LONG_PTR saved_style_ = 0;
  LONG_PTR saved_ex_style_ = 0;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_UI_WINDOW_CONTROLLER_H_
