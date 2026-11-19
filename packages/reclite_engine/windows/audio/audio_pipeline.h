#ifndef RECLITE_ENGINE_AUDIO_AUDIO_PIPELINE_H_
#define RECLITE_ENGINE_AUDIO_AUDIO_PIPELINE_H_

#include <cstdint>
#include <functional>
#include <mutex>
#include <optional>
#include <vector>

#include "audio_mixer.h"

namespace reclite_engine {

// Peak level per source: written on the recorder queue, read by the UI timer.
class LevelMeter {
 public:
  explicit LevelMeter(int source_count);
  void Record(int source, const std::vector<float>& samples);
  // Peaks since the last call, mapped to 0..1 on a -60..0 dBFS scale.
  std::vector<double> TakeLevels();

 private:
  std::mutex mutex_;
  std::vector<float> peaks_;
};

// Mixes up to two 48 kHz stereo sources onto the recording's media timeline
// (QPC ticks, pauses removed). Port of the macOS AudioPipeline. One thread only.
class AudioPipeline {
 public:
  static constexpr int kSampleRate = 48'000;
  // How long to wait for a quiet source before filling it with silence.
  static constexpr int64_t kMaxLag = 2'500'000;  // 250 ms

  using Output = std::function<void(const std::vector<float>& samples, int64_t time)>;

  explicit AudioPipeline(int source_count);

  // Receives each mixed buffer in order; never straddles the boundary.
  void set_output(Output output) { output_ = std::move(output); }
  LevelMeter& meter() { return meter_; }

  // Timeline zero: the first video frame. Audio before it is dropped.
  void Start(int64_t origin);
  bool started() const { return origin_.has_value(); }
  std::optional<int64_t> OutputTime() const;

  // Splits output exactly at `time`; `reached` runs after the last sample before it.
  void SetBoundary(int64_t time, std::function<void(int64_t)> reached);

  void Push(int source, const std::vector<float>& samples, int64_t time);

  // Emits what every source delivered, or up to `now - kMaxLag` when one is quiet;
  // never past `ceiling` (the pause point while paused).
  void Pump(int64_t now, std::optional<int64_t> ceiling);

  // Emits everything up to `end`, filling missing audio with silence.
  void Flush(int64_t end);

 private:
  int64_t FrameOf(int64_t time) const;
  int64_t TimeOf(int64_t frame) const;
  void Emit(int64_t frame);
  void FireBoundaryIfReached();

  int source_count_;
  AudioMixer mixer_;
  LevelMeter meter_;
  Output output_;
  std::optional<int64_t> origin_;
  std::optional<int64_t> boundary_frame_;
  std::function<void(int64_t)> on_boundary_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_AUDIO_AUDIO_PIPELINE_H_
