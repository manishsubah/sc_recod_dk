#include "frame_converter.h"

#include <algorithm>

#include "../core/strings.h"

namespace reclite_engine {
namespace {

D3D11_TEXTURE2D_DESC TextureDesc(UINT width, UINT height, DXGI_FORMAT format,
                                 UINT bind_flags) {
  D3D11_TEXTURE2D_DESC desc{};
  desc.Width = width;
  desc.Height = height;
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = format;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = bind_flags;
  return desc;
}

}  // namespace

std::unique_ptr<FrameConverter> FrameConverter::Create(
    ID3D11Device* device, UINT input_width, UINT input_height, RECT source,
    UINT output_width, UINT output_height, std::string* error) {
  auto converter = std::unique_ptr<FrameConverter>(new FrameConverter());
  converter->device_ = device;
  device->GetImmediateContext(&converter->context_);
  converter->input_width_ = input_width;
  converter->input_height_ = input_height;
  converter->output_width_ = output_width;
  converter->output_height_ = output_height;

  HRESULT hr = converter->device_.As(&converter->video_device_);
  if (SUCCEEDED(hr)) {
    hr = converter->context_.As(&converter->video_context_);
  }
  if (FAILED(hr)) {
    *error = "The graphics driver has no video processor (" + HresultMessage(hr) + ").";
    return nullptr;
  }

  D3D11_VIDEO_PROCESSOR_CONTENT_DESC content{};
  content.InputFrameFormat = D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE;
  content.InputWidth = input_width;
  content.InputHeight = input_height;
  content.OutputWidth = output_width;
  content.OutputHeight = output_height;
  content.InputFrameRate = {30, 1};
  content.OutputFrameRate = {30, 1};
  content.Usage = D3D11_VIDEO_USAGE_PLAYBACK_NORMAL;
  hr = converter->video_device_->CreateVideoProcessorEnumerator(
      &content, &converter->enumerator_);
  if (SUCCEEDED(hr)) {
    hr = converter->video_device_->CreateVideoProcessor(converter->enumerator_.Get(), 0,
                                                        &converter->processor_);
  }
  if (FAILED(hr)) {
    *error = "Could not set up colour conversion (" + HresultMessage(hr) + ").";
    return nullptr;
  }

  ID3D11VideoContext* vc = converter->video_context_.Get();
  ID3D11VideoProcessor* vp = converter->processor_.Get();
  const RECT destination{0, 0, static_cast<LONG>(output_width),
                         static_cast<LONG>(output_height)};
  vc->VideoProcessorSetStreamFrameFormat(vp, 0, D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE);
  vc->VideoProcessorSetStreamSourceRect(vp, 0, TRUE, &source);
  vc->VideoProcessorSetStreamDestRect(vp, 0, TRUE, &destination);
  vc->VideoProcessorSetOutputTargetRect(vp, TRUE, &destination);
  vc->VideoProcessorSetStreamAutoProcessingMode(vp, 0, FALSE);

  D3D11_VIDEO_PROCESSOR_COLOR_SPACE input_space{};
  input_space.RGB_Range = 0;  // Desktop frames are full-range RGB.
  vc->VideoProcessorSetStreamColorSpace(vp, 0, &input_space);
  D3D11_VIDEO_PROCESSOR_COLOR_SPACE output_space{};
  output_space.YCbCr_Matrix = 1;  // BT.709, matching the macOS output.
  output_space.Nominal_Range = D3D11_VIDEO_PROCESSOR_NOMINAL_RANGE_16_235;
  vc->VideoProcessorSetOutputColorSpace(vp, &output_space);

  // Capture textures can't be bound as processor input, so frames are copied here first.
  const auto input_desc =
      TextureDesc(input_width, input_height, DXGI_FORMAT_B8G8R8A8_UNORM,
                  D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET);
  hr = device->CreateTexture2D(&input_desc, nullptr, &converter->input_);
  if (SUCCEEDED(hr)) {
    D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC view{};
    view.ViewDimension = D3D11_VPIV_DIMENSION_TEXTURE2D;
    hr = converter->video_device_->CreateVideoProcessorInputView(
        converter->input_.Get(), converter->enumerator_.Get(), &view,
        &converter->input_view_);
  }
  if (FAILED(hr)) {
    *error = "Could not allocate video memory (" + HresultMessage(hr) + ").";
    return nullptr;
  }

  // Prefer textures the hardware encoder can read directly; older drivers reject the flag.
  for (const UINT flags : {static_cast<UINT>(D3D11_BIND_RENDER_TARGET | D3D11_BIND_VIDEO_ENCODER),
                           static_cast<UINT>(D3D11_BIND_RENDER_TARGET)}) {
    const auto probe_desc =
        TextureDesc(output_width, output_height, DXGI_FORMAT_NV12, flags);
    ComPtr<ID3D11Texture2D> probe;
    if (SUCCEEDED(device->CreateTexture2D(&probe_desc, nullptr, &probe))) {
      converter->output_bind_flags_ = flags;
      break;
    }
  }
  if (converter->output_bind_flags_ == 0) {
    *error = "The graphics card can't create NV12 video frames.";
    return nullptr;
  }
  return converter;
}

ComPtr<ID3D11Texture2D> FrameConverter::Convert(ID3D11Texture2D* bgra) {
  D3D11_TEXTURE2D_DESC desc{};
  bgra->GetDesc(&desc);
  if (desc.Width == input_width_ && desc.Height == input_height_) {
    context_->CopyResource(input_.Get(), bgra);
  } else {
    // A resized window or a resolution change: black where the frame has no
    // pixels, so an old picture never shows through.
    if (!input_target_ &&
        FAILED(device_->CreateRenderTargetView(input_.Get(), nullptr, &input_target_))) {
      return nullptr;
    }
    const float black[4] = {0, 0, 0, 1};
    context_->ClearRenderTargetView(input_target_.Get(), black);
    const D3D11_BOX box{0, 0, 0, std::min(desc.Width, input_width_),
                        std::min(desc.Height, input_height_), 1};
    context_->CopySubresourceRegion(input_.Get(), 0, 0, 0, 0, bgra, 0, &box);
  }

  const auto output_desc =
      TextureDesc(output_width_, output_height_, DXGI_FORMAT_NV12, output_bind_flags_);
  ComPtr<ID3D11Texture2D> output;
  if (FAILED(device_->CreateTexture2D(&output_desc, nullptr, &output))) {
    return nullptr;
  }
  D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC view{};
  view.ViewDimension = D3D11_VPOV_DIMENSION_TEXTURE2D;
  ComPtr<ID3D11VideoProcessorOutputView> output_view;
  if (FAILED(video_device_->CreateVideoProcessorOutputView(
          output.Get(), enumerator_.Get(), &view, &output_view))) {
    return nullptr;
  }

  D3D11_VIDEO_PROCESSOR_STREAM stream{};
  stream.Enable = TRUE;
  stream.pInputSurface = input_view_.Get();
  if (FAILED(video_context_->VideoProcessorBlt(processor_.Get(), output_view.Get(), 0,
                                               1, &stream))) {
    return nullptr;
  }
  return output;
}

}  // namespace reclite_engine
