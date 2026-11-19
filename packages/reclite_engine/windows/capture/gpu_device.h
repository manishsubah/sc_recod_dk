#ifndef RECLITE_ENGINE_CAPTURE_GPU_DEVICE_H_
#define RECLITE_ENGINE_CAPTURE_GPU_DEVICE_H_

#include <memory>
#include <string>

#include <d3d11.h>
#include <mfapi.h>

#include "../core/win.h"

namespace reclite_engine {

// One D3D11 device shared by capture, colour conversion and the hardware encoder,
// so frames stay on the GPU from screen to file.
class GpuDevice {
 public:
  static std::unique_ptr<GpuDevice> Create(std::string* error);

  ID3D11Device* device() const { return device_.Get(); }
  ID3D11DeviceContext* context() const { return context_.Get(); }
  IMFDXGIDeviceManager* manager() const { return manager_.Get(); }

 private:
  ComPtr<ID3D11Device> device_;
  ComPtr<ID3D11DeviceContext> context_;
  ComPtr<IMFDXGIDeviceManager> manager_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPTURE_GPU_DEVICE_H_
