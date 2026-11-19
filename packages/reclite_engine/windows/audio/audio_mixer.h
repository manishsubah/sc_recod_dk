#ifndef RECLITE_ENGINE_AUDIO_AUDIO_MIXER_H_
#define RECLITE_ENGINE_AUDIO_AUDIO_MIXER_H_

#include <cstdint>
#include <optional>
#include <vector>

namespace reclite_engine {

// Mixes stereo float streams placed on one shared 48 kHz frame timeline.
// Port of the macOS AudioMixer (same rules, same tests): gaps become silence,
// overlaps are trimmed, audio older than what was already emitted is dropped.
// Not thread-safe.
class AudioMixer {
 public:
  static constexpr int kChannels = 2;
  // Bounds the silence inserted for one gap, so a bad timestamp can't allocate minutes.
  static constexpr int64_t kMaxGapFrames = 48'000 * 5;

  explicit AudioMixer(int source_count);

  int64_t output_frame() const { return output_frame_; }

  // Timeline frame just past the last buffered sample; empty when nothing is queued.
  std::optional<int64_t> EndFrame(int source) const;

  // `samples` are interleaved stereo; `start_frame` is the first one's timeline position.
  void Push(int source, const std::vector<float>& samples, int64_t start_frame);

  // Mixes and consumes frames [output_frame, frame). Missing samples are silence.
  std::vector<float> Pull(int64_t frame);

 private:
  struct Queue {
    std::vector<float> samples;
    size_t head = 0;  // Index of the first unconsumed sample.
    int64_t start = 0;  // Timeline frame of samples[head].
    int64_t frames() const {
      return static_cast<int64_t>((samples.size() - head) / kChannels);
    }
  };

  void Consume(Queue& queue, int64_t frames);

  std::vector<Queue> queues_;
  int64_t output_frame_ = 0;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_AUDIO_AUDIO_MIXER_H_
