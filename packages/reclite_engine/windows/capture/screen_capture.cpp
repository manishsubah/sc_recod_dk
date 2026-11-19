#include "screen_capture.h"

#include <dxgi.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Metadata.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <winrt/Windows.Graphics.DirectX.h>

#include <mutex>

#include "../core/strings.h"

namespace reclite_engine {

namespace wgc = winrt::Windows::Graphics::Capture;
namespace wgd = winrt::Windows::Graphics::DirectX;

struct ScreenCapture::WinRtState {
  wgc::GraphicsCaptureItem item{nullptr};
  wgd::Direct3D11::IDirect3DDevice device{nullptr};
  wgc::Direct3D11CaptureFramePool pool{nullptr};
  wgc::GraphicsCaptureSession session{nullptr};
  wgc::Direct3D11CaptureFramePool::FrameArrived_revoker frame_arrived;
  std::mutex handler_mutex;
  FrameHandler handler;
};

bool ScreenCapture::IsSupported() {
  try {
    return wgc::GraphicsCaptureSession::IsSupported();
  } catch (...) {
    return false;
  }
}

std::unique_ptr<ScreenCapture> ScreenCapture::Create(HMONITOR monitor,
                                                     ID3D11Device* device,
                                                     std::string* error) {
  auto capture = std::unique_ptr<ScreenCapture>(new ScreenCapture());
  capture->state_ = std::make_unique<WinRtState>();
  try {
    ComPtr<IDXGIDevice> dxgi;
    winrt::check_hresult(device->QueryInterface(IID_PPV_ARGS(&dxgi)));
    winrt::com_ptr<::IInspectable> inspectable;
    winrt::check_hresult(
        ::CreateDirect3D11DeviceFromDXGIDevice(dxgi.Get(), inspectable.put()));
    capture->state_->device = inspectable.as<wgd::Direct3D11::IDirect3DDevice>();

    auto interop = winrt::get_activation_factory<wgc::GraphicsCaptureItem,
                                                 ::IGraphicsCaptureItemInterop>();
    winrt::check_hresult(interop->CreateForMonitor(
        monitor, winrt::guid_of<wgc::GraphicsCaptureItem>(),
        winrt::put_abi(capture->state_->item)));

    const auto size = capture->state_->item.Size();
    capture->width_ = size.Width;
    capture->height_ = size.Height;
  } catch (const winrt::hresult_error& e) {
    *error = "Screen capture is not available (" + HresultMessage(e.code()) + ").";
    return nullptr;
  }
  return capture;
}

ScreenCapture::~ScreenCapture() { Stop(); }

bool ScreenCapture::Start(FrameHandler handler, std::string* error) {
  WinRtState* state = state_.get();
  {
    std::lock_guard<std::mutex> lock(state->handler_mutex);
    state->handler = std::move(handler);
  }
  try {
    // Two buffers: if conversion falls behind, Windows drops frames instead of queueing.
    state->pool = wgc::Direct3D11CaptureFramePool::CreateFreeThreaded(
        state->device, wgd::DirectXPixelFormat::B8G8R8A8UIntNormalized, 2,
        state->item.Size());
    state->session = state->pool.CreateCaptureSession(state->item);

    using winrt::Windows::Foundation::Metadata::ApiInformation;
    if (ApiInformation::IsPropertyPresent(L"Windows.Graphics.Capture.GraphicsCaptureSession",
                                          L"IsCursorCaptureEnabled")) {
      state->session.IsCursorCaptureEnabled(true);
    }
    // Windows 11: no yellow border around the captured screen.
    if (ApiInformation::IsPropertyPresent(L"Windows.Graphics.Capture.GraphicsCaptureSession",
                                          L"IsBorderRequired")) {
      state->session.IsBorderRequired(false);
    }

    state->frame_arrived = state->pool.FrameArrived(
        winrt::auto_revoke, [state](const wgc::Direct3D11CaptureFramePool& pool,
                                    const winrt::Windows::Foundation::IInspectable&) {
          const auto frame = pool.TryGetNextFrame();
          if (!frame) {
            return;
          }
          auto access = frame.Surface()
                            .as<::Windows::Graphics::DirectX::Direct3D11::
                                    IDirect3DDxgiInterfaceAccess>();
          ComPtr<ID3D11Texture2D> texture;
          if (SUCCEEDED(access->GetInterface(IID_PPV_ARGS(&texture)))) {
            std::lock_guard<std::mutex> lock(state->handler_mutex);
            if (state->handler) {
              state->handler(texture.Get(), frame.SystemRelativeTime().count());
            }
          }
          frame.Close();  // Returns the buffer to the pool right away.
        });
    state->session.StartCapture();
  } catch (const winrt::hresult_error& e) {
    *error = "Could not start screen capture (" + HresultMessage(e.code()) + ").";
    return false;
  }
  return true;
}

void ScreenCapture::Stop() {
  if (!state_) {
    return;
  }
  {
    std::lock_guard<std::mutex> lock(state_->handler_mutex);
    state_->handler = nullptr;
  }
  state_->frame_arrived.revoke();
  try {
    if (state_->session) {
      state_->session.Close();
      state_->session = nullptr;
    }
    if (state_->pool) {
      state_->pool.Close();
      state_->pool = nullptr;
    }
  } catch (...) {
  }
}

}  // namespace reclite_engine
