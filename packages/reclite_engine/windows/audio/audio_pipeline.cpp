#include "audio_pipeline.h"

#include <algorithm>
#include <cmath>

#include "../core/ticks.h"

namespace reclite_engine {

LevelMeter::LevelMeter(int source_count)
    : peaks_(static_cast<size_t>(source_count), 0.0f) {}

void LevelMeter::Record(int source, const std::vector<float>& samples) {
  float peak = 0.0f;
  for (const float sample : samples) {
    peak = std::max(peak, std::fabs(sample));
  }
  std::lock_guard<std::mutex> lock(mutex_);
  float& stored = peaks_[static_cast<size_t>(source)];
  stored = std::max(stored, peak);
}

std::vector<double> LevelMeter::TakeLevels() {
  std::vector<float> current;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    current = peaks_;
    std::fill(peaks_.begin(), peaks_.end(), 0.0f);
  }
  std::vector<double> levels;
  levels.reserve(current.size());
  for (const float peak : current) {
    if (peak <= 0.0f) {
      levels.push_back(0.0);
      continue;
    }
    const double db = 20.0 * std::log10(static_cast<double>(peak));
    levels.push_back(std::clamp((db + 60.0) / 60.0, 0.0, 1.0));
  }
  return levels;
}

AudioPipeline::AudioPipeline(int source_count)
    : source_count_(source_count), mixer_(source_count), meter_(source_count) {}

void AudioPipeline::Start(int64_t origin) {
  if (!origin_) {
    origin_ = origin;
  }
}

std::optional<int64_t> AudioPipeline::OutputTime() const {
  if (!origin_) {
    return std::nullopt;
  }
  return TimeOf(mixer_.output_frame());
}

void AudioPipeline::SetBoundary(int64_t time, std::function<void(int64_t)> reached) {
  if (!origin_) {
    return;
  }
  boundary_frame_ = FrameOf(time);
  on_boundary_ = std::move(reached);
  FireBoundaryIfReached();
}

void AudioPipeline::Push(int source, const std::vector<float>& samples, int64_t time) {
  meter_.Record(source, samples);
  if (!origin_) {
    return;
  }
  mixer_.Push(source, samples, FrameOf(time));
}

void AudioPipeline::Pump(int64_t now, std::optional<int64_t> ceiling) {
  if (!origin_) {
    return;
  }
  const int64_t now_frame = FrameOf(now);
  const int64_t lag_frame = now_frame - (kMaxLag * kSampleRate) / kTicksPerSecond;
  int64_t ready = INT64_MAX;
  for (int source = 0; source < source_count_; ++source) {
    ready = std::min(ready, mixer_.EndFrame(source).value_or(mixer_.output_frame()));
  }
  if (source_count_ == 0) {
    ready = mixer_.output_frame();
  }
  int64_t target = std::min(now_frame, std::max(ready, lag_frame));
  if (ceiling) {
    target = std::min(target, FrameOf(*ceiling));
  }
  Emit(target);
}

void AudioPipeline::Flush(int64_t end) {
  if (origin_) {
    Emit(FrameOf(end));
  }
}

int64_t AudioPipeline::FrameOf(int64_t time) const {
  const double seconds = TicksToSeconds(time - *origin_);
  return static_cast<int64_t>(std::llround(seconds * kSampleRate));
}

int64_t AudioPipeline::TimeOf(int64_t frame) const {
  return *origin_ + static_cast<int64_t>(std::llround(
                        static_cast<double>(frame) * kTicksPerSecond / kSampleRate));
}

void AudioPipeline::Emit(int64_t frame) {
  while (frame > mixer_.output_frame()) {
    int64_t end = frame;
    if (boundary_frame_ && *boundary_frame_ > mixer_.output_frame() &&
        *boundary_frame_ < end) {
      end = *boundary_frame_;
    }
    const int64_t first = mixer_.output_frame();
    const std::vector<float> samples = mixer_.Pull(end);
    if (output_ && !samples.empty()) {
      output_(samples, TimeOf(first));
    }
    FireBoundaryIfReached();
  }
}

void AudioPipeline::FireBoundaryIfReached() {
  if (!boundary_frame_ || mixer_.output_frame() < *boundary_frame_) {
    return;
  }
  const int64_t time = TimeOf(*boundary_frame_);
  auto callback = std::move(on_boundary_);
  boundary_frame_.reset();
  on_boundary_ = nullptr;
  if (callback) {
    callback(time);
  }
}

}  // namespace reclite_engine
