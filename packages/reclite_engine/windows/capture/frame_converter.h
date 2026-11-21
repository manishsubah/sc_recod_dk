#ifndef RECLITE_ENGINE_CAPTURE_FRAME_CONVERTER_H_
#define RECLITE_ENGINE_CAPTURE_FRAME_CONVERTER_H_

#include <memory>
#include <string>

#include <d3d11.h>

#include "../core/win.h"

namespace reclite_engine {

// BGRA screen frames -> NV12 encoder frames on the GPU (crop + scale + BT.709),
// using the D3D11 video processor. Use from one thread at a time.
class FrameConverter {
 public:
  // `source` is the part of the input to keep (whole frame or a selected area).
  static std::unique_ptr<FrameConverter> Create(ID3D11Device* device, UINT input_width,
                                                UINT input_height, RECT source,
                                                UINT output_width, UINT output_height,
                                                std::string* error);

  // A new NV12 texture per frame (the encoder may still read earlier ones).
  ComPtr<ID3D11Texture2D> Convert(ID3D11Texture2D* bgra);

 private:
  ComPtr<ID3D11Device> device_;
  ComPtr<ID3D11DeviceContext> context_;
  ComPtr<ID3D11VideoDevice> video_device_;
  ComPtr<ID3D11VideoContext> video_context_;
  ComPtr<ID3D11VideoProcessorEnumerator> enumerator_;
  ComPtr<ID3D11VideoProcessor> processor_;
  ComPtr<ID3D11Texture2D> input_;
  ComPtr<ID3D11VideoProcessorInputView> input_view_;
  ComPtr<ID3D11RenderTargetView> input_target_;
  UINT input_width_ = 0;
  UINT input_height_ = 0;
  UINT output_width_ = 0;
  UINT output_height_ = 0;
  UINT output_bind_flags_ = 0;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPTURE_FRAME_CONVERTER_H_
