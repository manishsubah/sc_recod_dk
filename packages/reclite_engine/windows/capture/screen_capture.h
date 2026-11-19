#ifndef RECLITE_ENGINE_CAPTURE_SCREEN_CAPTURE_H_
#define RECLITE_ENGINE_CAPTURE_SCREEN_CAPTURE_H_

#include <cstdint>
#include <functional>
#include <memory>
#include <string>

#include <d3d11.h>

#include "../core/win.h"

namespace reclite_engine {

// One monitor captured with Windows Graphics Capture. Frames arrive only when the
// screen changes (variable frame rate), on a capture thread.
class ScreenCapture {
 public:
  // `frame` is only valid during the call; copy it before returning. `time` is in
  // QPC ticks (see core/clock.h).
  using FrameHandler = std::function<void(ID3D11Texture2D* frame, int64_t time)>;

  static bool IsSupported();

  static std::unique_ptr<ScreenCapture> Create(HMONITOR monitor, ID3D11Device* device,
                                               std::string* error);
  ~ScreenCapture();

  int width() const { return width_; }
  int height() const { return height_; }

  bool Start(FrameHandler handler, std::string* error);
  void Stop();

 private:
  ScreenCapture() = default;

  struct WinRtState;
  std::unique_ptr<WinRtState> state_;
  int width_ = 0;
  int height_ = 0;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPTURE_SCREEN_CAPTURE_H_
