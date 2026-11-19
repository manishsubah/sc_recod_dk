#ifndef RECLITE_ENGINE_CAPTURE_DISPLAY_CATALOG_H_
#define RECLITE_ENGINE_CAPTURE_DISPLAY_CATALOG_H_

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "../core/win.h"

namespace reclite_engine {

struct DisplayInfo {
  // Stable while the setup doesn't change: the N in \\.\DISPLAYN.
  int64_t id = 0;
  std::string name;
  HMONITOR monitor = nullptr;
  // Physical pixels in virtual-desktop coordinates (the runner is per-monitor DPI aware).
  RECT bounds{};
  bool is_primary = false;

  int width() const { return bounds.right - bounds.left; }
  int height() const { return bounds.bottom - bounds.top; }
};

// Connected monitors, primary first.
std::vector<DisplayInfo> ListDisplays();

std::optional<DisplayInfo> FindDisplay(int64_t id);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPTURE_DISPLAY_CATALOG_H_
