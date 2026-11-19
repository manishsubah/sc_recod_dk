#include "gpu_device.h"

#include <d3d10.h>

#include "../core/strings.h"

namespace reclite_engine {

std::unique_ptr<GpuDevice> GpuDevice::Create(std::string* error) {
  auto gpu = std::unique_ptr<GpuDevice>(new GpuDevice());

  const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0,
                                      D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0};
  HRESULT hr = ::D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT | D3D11_CREATE_DEVICE_VIDEO_SUPPORT, levels,
      ARRAYSIZE(levels), D3D11_SDK_VERSION, &gpu->device_, nullptr, &gpu->context_);
  if (FAILED(hr)) {
    *error = "Could not open the graphics card (" + HresultMessage(hr) + ").";
    return nullptr;
  }

  // The encoder uses this device from its own threads.
  ComPtr<ID3D10Multithread> multithread;
  if (SUCCEEDED(gpu->device_.As(&multithread))) {
    multithread->SetMultithreadProtected(TRUE);
  }

  UINT token = 0;
  hr = ::MFCreateDXGIDeviceManager(&token, &gpu->manager_);
  if (SUCCEEDED(hr)) {
    hr = gpu->manager_->ResetDevice(gpu->device_.Get(), token);
  }
  if (FAILED(hr)) {
    *error = "Could not prepare the video encoder (" + HresultMessage(hr) + ").";
    return nullptr;
  }
  return gpu;
}

}  // namespace reclite_engine
