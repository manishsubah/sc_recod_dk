#ifndef RECLITE_ENGINE_UI_GLOBAL_SHORTCUTS_H_
#define RECLITE_ENGINE_UI_GLOBAL_SHORTCUTS_H_

#include <functional>
#include <string>
#include <vector>

#include "../core/win.h"

namespace reclite_engine {

// System-wide hotkeys (RegisterHotKey) delivered to a hidden message-only window,
// so they work while another app has focus. Use on the platform thread only.
class GlobalShortcuts {
 public:
  struct Shortcut {
    std::string key;  // "A"-"Z", "0"-"9", "F1"-"F12"
    bool control = false;
    bool alt = false;
    bool shift = false;
    bool meta = false;
  };

  // Called on the platform thread with the shortcut's index in the last Set().
  explicit GlobalShortcuts(std::function<void(int)> on_pressed);
  ~GlobalShortcuts();

  GlobalShortcuts(const GlobalShortcuts&) = delete;
  GlobalShortcuts& operator=(const GlobalShortcuts&) = delete;

  // Replaces all shortcuts. Returns the indexes that could not be registered
  // (unknown key, or already used by another app).
  std::vector<int> Set(const std::vector<Shortcut>& shortcuts);

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  void Clear();

  HWND window_ = nullptr;
  std::function<void(int)> on_pressed_;
  std::vector<int> registered_ids_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_UI_GLOBAL_SHORTCUTS_H_
