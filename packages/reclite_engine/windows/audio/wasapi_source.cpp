#include "wasapi_source.h"

#include "../core/win.h"

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>

#include <chrono>
#include <cstring>
#include <future>
#include <utility>

#include "../core/strings.h"

namespace reclite_engine {
namespace {

#ifndef E_NOTFOUND
#define E_NOTFOUND HRESULT_FROM_WIN32(ERROR_NOT_FOUND)
#endif

constexpr REFERENCE_TIME kBufferDuration = 2'000'000;  // 200 ms
constexpr DWORD kPollMilliseconds = 10;

WAVEFORMATEX StereoFloat48k() {
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
  format.nChannels = 2;
  format.nSamplesPerSec = 48'000;
  format.wBitsPerSample = 32;
  format.nBlockAlign = 8;
  format.nAvgBytesPerSec = 48'000 * 8;
  format.cbSize = 0;
  return format;
}

struct Device {
  ComPtr<IAudioClient> client;
  ComPtr<IAudioCaptureClient> capture;
};

// Opens the current default device. AUTOCONVERTPCM makes Windows resample and
// remix to 48 kHz stereo float, whatever the device's native format.
HRESULT Open(WasapiSource::Kind kind, Device* device) {
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    return hr;
  }
  const bool loopback = kind == WasapiSource::Kind::kSystemLoopback;
  ComPtr<IMMDevice> endpoint;
  hr = enumerator->GetDefaultAudioEndpoint(loopback ? eRender : eCapture, eConsole,
                                           &endpoint);
  if (FAILED(hr)) {
    return hr;
  }
  hr = endpoint->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(device->client.ReleaseAndGetAddressOf()));
  if (FAILED(hr)) {
    return hr;
  }
  auto format = StereoFloat48k();
  const DWORD flags = (loopback ? AUDCLNT_STREAMFLAGS_LOOPBACK : 0) |
                      AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                      AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
  hr = device->client->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, kBufferDuration, 0,
                                  &format, nullptr);
  if (FAILED(hr)) {
    return hr;
  }
  hr = device->client->GetService(IID_PPV_ARGS(&device->capture));
  if (FAILED(hr)) {
    return hr;
  }
  return device->client->Start();
}

std::string OpenErrorMessage(WasapiSource::Kind kind, HRESULT hr) {
  if (kind == WasapiSource::Kind::kMicrophone) {
    if (hr == E_ACCESSDENIED) {
      return "Windows blocks microphone access for desktop apps. Turn it on in "
             "Settings > Privacy > Microphone.";
    }
    if (hr == E_NOTFOUND) {
      return "No microphone was found.";
    }
    return "Could not open the microphone (" + HresultMessage(hr) + ").";
  }
  if (hr == E_NOTFOUND) {
    return "No speakers or headphones are enabled, so there is no system sound to record.";
  }
  return "Could not open system sound (" + HresultMessage(hr) + ").";
}

}  // namespace

WasapiSource::WasapiSource(Kind kind, Handler handler)
    : kind_(kind), handler_(std::move(handler)) {}

WasapiSource::~WasapiSource() { Stop(); }

bool WasapiSource::Start(std::string* error) {
  auto ready = std::make_shared<std::promise<std::pair<bool, std::string>>>();
  auto opened = ready->get_future();
  stopping_ = false;
  thread_ = std::thread([this, ready] {
    Run([ready](bool ok, std::string message) {
      ready->set_value({ok, std::move(message)});
    });
  });
  const auto result = opened.get();
  if (!result.first) {
    *error = result.second;
    Stop();
  }
  return result.first;
}

void WasapiSource::Stop() {
  stopping_ = true;
  if (thread_.joinable()) {
    thread_.join();
  }
}

void WasapiSource::Run(std::function<void(bool, std::string)> ready) {
  ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  Device device;
  HRESULT hr = Open(kind_, &device);
  ready(SUCCEEDED(hr), SUCCEEDED(hr) ? std::string() : OpenErrorMessage(kind_, hr));
  if (FAILED(hr)) {
    ::CoUninitialize();
    return;
  }

  while (!stopping_) {
    ::Sleep(kPollMilliseconds);
    UINT32 packet = 0;
    hr = device.capture->GetNextPacketSize(&packet);
    while (SUCCEEDED(hr) && packet > 0 && !stopping_) {
      BYTE* data = nullptr;
      UINT32 frames = 0;
      DWORD flags = 0;
      UINT64 position = 0;
      UINT64 qpc_time = 0;  // 100 ns units on the QPC clock.
      hr = device.capture->GetBuffer(&data, &frames, &flags, &position, &qpc_time);
      if (FAILED(hr)) {
        break;
      }
      std::vector<float> samples(static_cast<size_t>(frames) * 2, 0.0f);
      if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0 && data != nullptr) {
        std::memcpy(samples.data(), data, samples.size() * sizeof(float));
      }
      device.capture->ReleaseBuffer(frames);
      if (!samples.empty()) {
        handler_(std::move(samples), static_cast<int64_t>(qpc_time));
      }
      hr = device.capture->GetNextPacketSize(&packet);
    }

    // The default device changed or was unplugged: reopen the new default one.
    if (hr == AUDCLNT_E_DEVICE_INVALIDATED) {
      device = Device();
      while (!stopping_ && FAILED(Open(kind_, &device))) {
        device = Device();
        ::Sleep(250);
      }
    }
  }
  if (device.client) {
    device.client->Stop();
  }
  device = Device();
  ::CoUninitialize();
}

bool WasapiSource::MicrophoneAccessible() {
  // The platform thread already has COM; only balance an initialisation we made.
  const HRESULT com = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  bool accessible = false;
  {
    Device device;
    accessible = SUCCEEDED(Open(Kind::kMicrophone, &device));
    if (device.client) {
      device.client->Stop();
    }
  }
  if (SUCCEEDED(com)) {
    ::CoUninitialize();
  }
  return accessible;
}

}  // namespace reclite_engine
