#ifndef RECLITE_ENGINE_AUDIO_WASAPI_SOURCE_H_
#define RECLITE_ENGINE_AUDIO_WASAPI_SOURCE_H_

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <thread>
#include <vector>

namespace reclite_engine {

// System sound (loopback of the default output) or the default microphone, as
// 48 kHz interleaved stereo float. Follows the default device when it changes
// (e.g. headphones plugged in) without stopping.
class WasapiSource {
 public:
  enum class Kind { kSystemLoopback, kMicrophone };

  // Called on the capture thread. `time` is the QPC tick of the first frame.
  using Handler = std::function<void(std::vector<float>&& samples, int64_t time)>;

  WasapiSource(Kind kind, Handler handler);
  ~WasapiSource();

  WasapiSource(const WasapiSource&) = delete;
  WasapiSource& operator=(const WasapiSource&) = delete;

  // Returns once the device is open (or failed to open).
  bool Start(std::string* error);
  void Stop();

  // False when there is no microphone or Windows privacy settings block desktop apps.
  static bool MicrophoneAccessible();

 private:
  void Run(std::function<void(bool, std::string)> ready);

  Kind kind_;
  Handler handler_;
  std::atomic<bool> stopping_{false};
  std::thread thread_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_AUDIO_WASAPI_SOURCE_H_
