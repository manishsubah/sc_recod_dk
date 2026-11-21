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
  wgc::GraphicsCaptureItem::Closed_revoker closed;
  winrt::Windows::Graphics::SizeInt32 pool_size{};
  std::mutex handler_mutex;
  FrameHandler handler;
  std::function<void()> on_closed;
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
  return CreateFor(
      [monitor](ScreenCapture& capture) {
        auto interop = winrt::get_activation_factory<wgc::GraphicsCaptureItem,
                                                     ::IGraphicsCaptureItemInterop>();
        winrt::check_hresult(interop->CreateForMonitor(
            monitor, winrt::guid_of<wgc::GraphicsCaptureItem>(),
            winrt::put_abi(capture.state_->item)));
      },
      device, error);
}

std::unique_ptr<ScreenCapture> ScreenCapture::CreateForWindow(HWND window,
                                                              ID3D11Device* device,
                                                              std::string* error) {
  return CreateFor(
      [window](ScreenCapture& capture) {
        auto interop = winrt::get_activation_factory<wgc::GraphicsCaptureItem,
                                                     ::IGraphicsCaptureItemInterop>();
        winrt::check_hresult(interop->CreateForWindow(
            window, winrt::guid_of<wgc::GraphicsCaptureItem>(),
            winrt::put_abi(capture.state_->item)));
      },
      device, error);
}

std::unique_ptr<ScreenCapture> ScreenCapture::CreateFor(
    const std::function<void(ScreenCapture&)>& make_item, ID3D11Device* device,
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

    make_item(*capture);

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

void ScreenCapture::SetClosedHandler(std::function<void()> on_closed) {
  std::lock_guard<std::mutex> lock(state_->handler_mutex);
  state_->on_closed = std::move(on_closed);
}

bool ScreenCapture::Start(bool show_cursor, FrameHandler handler, std::string* error) {
  WinRtState* state = state_.get();
  {
    std::lock_guard<std::mutex> lock(state->handler_mutex);
    state->handler = std::move(handler);
  }
  try {
    // Two buffers: if conversion falls behind, Windows drops frames instead of queueing.
    state->pool_size = state->item.Size();
    state->pool = wgc::Direct3D11CaptureFramePool::CreateFreeThreaded(
        state->device, wgd::DirectXPixelFormat::B8G8R8A8UIntNormalized, 2,
        state->pool_size);
    state->closed = state->item.Closed(
        winrt::auto_revoke, [state](const wgc::GraphicsCaptureItem&,
                                    const winrt::Windows::Foundation::IInspectable&) {
          std::function<void()> on_closed;
          {
            std::lock_guard<std::mutex> lock(state->handler_mutex);
            on_closed = std::move(state->on_closed);
            state->on_closed = nullptr;
          }
          if (on_closed) on_closed();
        });
    state->session = state->pool.CreateCaptureSession(state->item);

    using winrt::Windows::Foundation::Metadata::ApiInformation;
    if (ApiInformation::IsPropertyPresent(L"Windows.Graphics.Capture.GraphicsCaptureSession",
                                          L"IsCursorCaptureEnabled")) {
      state->session.IsCursorCaptureEnabled(show_cursor);
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
          const auto content = frame.ContentSize();
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

          // A resized window needs buffers of its new size; the converter fits
          // what arrives into the output size.
          if (content.Width > 0 && content.Height > 0 &&
              (content.Width != state->pool_size.Width ||
               content.Height != state->pool_size.Height)) {
            state->pool_size = content;
            pool.Recreate(state->device, wgd::DirectXPixelFormat::B8G8R8A8UIntNormalized,
                          2, content);
          }
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
    state_->on_closed = nullptr;
  }
  state_->frame_arrived.revoke();
  state_->closed.revoke();
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
