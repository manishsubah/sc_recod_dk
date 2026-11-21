#ifndef RECLITE_ENGINE_CAPTURE_WINDOW_CATALOG_H_
#define RECLITE_ENGINE_CAPTURE_WINDOW_CATALOG_H_

#include <string>
#include <vector>

#include "../core/win.h"

namespace reclite_engine {

struct WindowInfo {
  HWND hwnd = nullptr;
  std::string title;
  std::string app_name;  // Executable name without ".exe", e.g. "chrome".
  int width = 0;         // Physical pixels, without the invisible resize border.
  int height = 0;
};

// Normal app windows a user would want to record, top of the Z-order first.
// Skips hidden, minimized, cloaked (e.g. suspended Store apps) and tool windows,
// the desktop and taskbar, and windows of `exclude_process` (RecLite itself).
std::vector<WindowInfo> ListCaptureWindows(DWORD exclude_process);

// The window if it is still open and recordable.
bool IsRecordableWindow(HWND hwnd);

std::string WindowTitle(HWND hwnd);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPTURE_WINDOW_CATALOG_H_
