#ifndef RECLITE_ENGINE_WRITER_SEGMENTED_RECORDER_H_
#define RECLITE_ENGINE_WRITER_SEGMENTED_RECORDER_H_

#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include "../audio/audio_pipeline.h"
#include "../core/serial_queue.h"
#include "../core/ticks.h"
#include "segment_writer.h"

namespace reclite_engine {

// One recording written as consecutive MP4 parts, with pause/resume — the Windows
// port of the macOS SegmentedRecorder (same rules).
//
// Inputs carry host (QPC) times; everything runs on a media timeline with paused
// time removed. Call every method on `queue` except Snapshot().
class SegmentedRecorder : public std::enable_shared_from_this<SegmentedRecorder> {
 public:
  struct Settings {
    int64_t segment_duration = 0;
    SegmentWriter::Format format;
    int audio_sources = 0;
    // File for part `index`, expected to start `starts_in_seconds` from now.
    std::function<std::filesystem::path(int index, double starts_in_seconds)> make_path;
  };

  struct Part {
    int index = 0;
    std::filesystem::path path;
    int64_t duration = 0;
    int64_t bytes = 0;
  };

  struct Stats {
    int64_t elapsed = 0;
    int part_index = 1;
    int64_t bytes_written = 0;
    int dropped_frames = 0;
    std::string failure;
  };

  using StopCallback = std::function<void(std::vector<Part> parts, std::string error)>;

  // The next part's writer is created this long before the boundary.
  static constexpr int64_t kPrewarmLead = 10 * kTicksPerSecond;
  // With no new frames and no audio, the boundary is enforced this long after it passes.
  static constexpr int64_t kRotationGrace = 5'000'000;  // 500 ms

  static std::shared_ptr<SegmentedRecorder> Create(Settings settings, SerialQueue* queue,
                                                   IMFDXGIDeviceManager* manager,
                                                   std::string* error);

  // Runs on `queue` after each part is closed and renamed to .mp4.
  std::function<void(const Part&)> on_part_finished;
  // Runs on `queue` the first time writing fails; the recording should then stop.
  std::function<void(const std::string&)> on_failure;

  LevelMeter* meter() { return audio_ ? &audio_->meter() : nullptr; }

  // False while paused or stopped: lets the caller skip GPU work for unused frames.
  bool WantsVideo(int64_t host_time) const;
  void AppendVideo(ID3D11Texture2D* nv12, int64_t host_time);
  void AppendAudio(int source, const std::vector<float>& samples, int64_t host_time,
                   int64_t host_now);
  // Call about every 100 ms.
  void Tick(int64_t host_now);
  void Pause(int64_t host_now);
  void Resume(int64_t host_now);
  void Stop(int64_t host_now, StopCallback done);

  // Any thread.
  Stats Snapshot() const;

 private:
  SegmentedRecorder(Settings settings, SerialQueue* queue, IMFDXGIDeviceManager* manager);

  std::optional<int64_t> boundary() const;
  int64_t Media(int64_t host_time) const { return host_time - pause_offset_; }
  void PumpAudio(int64_t host_now);
  void Rotate(int64_t time);
  void ArmAudioBoundary();
  void AudioReachedBoundary();
  void FinishPart(std::shared_ptr<SegmentWriter> part, int64_t end);
  void OnPartFinished(bool ok, Part part, int dropped, const std::string& error);
  void Fail(const std::string& error);
  void PublishStats(int64_t host_now);
  std::shared_ptr<SegmentWriter> MakeWriter(int index, double starts_in_seconds,
                                            std::string* error);

  Settings settings_;
  SerialQueue* queue_;
  ComPtr<IMFDXGIDeviceManager> manager_;
  std::unique_ptr<AudioPipeline> audio_;

  std::shared_ptr<SegmentWriter> writer_;
  std::shared_ptr<SegmentWriter> audio_target_;
  std::shared_ptr<SegmentWriter> draining_;
  int64_t draining_end_ = 0;
  std::shared_ptr<SegmentWriter> prepared_;
  std::optional<int64_t> part_start_;
  std::optional<int64_t> origin_;
  int64_t pause_offset_ = 0;
  std::optional<int64_t> paused_at_;
  bool stopped_ = false;
  int pending_finishes_ = 0;
  StopCallback stop_done_;
  std::vector<Part> parts_;
  int64_t completed_bytes_ = 0;
  int completed_drops_ = 0;
  std::string failure_;

  mutable std::mutex stats_mutex_;
  Stats stats_;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_WRITER_SEGMENTED_RECORDER_H_
