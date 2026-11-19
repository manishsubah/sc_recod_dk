#include "audio_mixer.h"

#include <algorithm>

namespace reclite_engine {

AudioMixer::AudioMixer(int source_count) : queues_(static_cast<size_t>(source_count)) {}

std::optional<int64_t> AudioMixer::EndFrame(int source) const {
  const Queue& queue = queues_[static_cast<size_t>(source)];
  const int64_t frames = queue.frames();
  if (frames == 0) {
    return std::nullopt;
  }
  return queue.start + frames;
}

void AudioMixer::Push(int source, const std::vector<float>& samples,
                      int64_t start_frame) {
  Queue& queue = queues_[static_cast<size_t>(source)];
  int64_t frame_count = static_cast<int64_t>(samples.size() / kChannels);
  if (frame_count <= 0) {
    return;
  }
  int64_t first = 0;
  int64_t start = start_frame;

  if (start < output_frame_) {
    const int64_t late = output_frame_ - start;
    if (late >= frame_count) {
      return;
    }
    first += late;
    frame_count -= late;
    start = output_frame_;
  }

  if (queue.frames() == 0) {
    queue.samples.clear();
    queue.head = 0;
    queue.start = start;
  } else {
    const int64_t end = queue.start + queue.frames();
    if (start > end) {
      const int64_t gap = std::min(start - end, kMaxGapFrames);
      queue.samples.insert(queue.samples.end(), static_cast<size_t>(gap * kChannels), 0.0f);
    } else if (start < end) {
      const int64_t overlap = end - start;
      if (overlap >= frame_count) {
        return;
      }
      first += overlap;
      frame_count -= overlap;
    }
  }

  const auto from = samples.begin() + static_cast<std::ptrdiff_t>(first * kChannels);
  queue.samples.insert(queue.samples.end(), from,
                       from + static_cast<std::ptrdiff_t>(frame_count * kChannels));
}

std::vector<float> AudioMixer::Pull(int64_t frame) {
  if (frame <= output_frame_) {
    return {};
  }
  const int64_t count = frame - output_frame_;
  std::vector<float> out(static_cast<size_t>(count * kChannels), 0.0f);

  for (Queue& queue : queues_) {
    const int64_t available = queue.frames();
    if (available == 0) {
      continue;
    }
    // The queue may start before the window (already partly consumed) or inside it.
    const int64_t into = std::max<int64_t>(0, queue.start - output_frame_);
    const int64_t skip = std::max<int64_t>(0, output_frame_ - queue.start);
    const int64_t usable = std::max<int64_t>(0, std::min(count - into, available - skip));
    const size_t src = queue.head + static_cast<size_t>(skip * kChannels);
    const size_t dst = static_cast<size_t>(into * kChannels);
    for (size_t i = 0; i < static_cast<size_t>(usable * kChannels); ++i) {
      out[dst + i] += queue.samples[src + i];
    }
    Consume(queue, std::min(available, std::max<int64_t>(0, frame - queue.start)));
  }

  for (float& sample : out) {
    sample = std::clamp(sample, -1.0f, 1.0f);
  }
  output_frame_ = frame;
  return out;
}

void AudioMixer::Consume(Queue& queue, int64_t frames) {
  queue.head += static_cast<size_t>(frames * kChannels);
  queue.start += frames;
  if (queue.head >= static_cast<size_t>(48'000 * kChannels)) {
    queue.samples.erase(queue.samples.begin(),
                        queue.samples.begin() + static_cast<std::ptrdiff_t>(queue.head));
    queue.head = 0;
  }
}

}  // namespace reclite_engine
