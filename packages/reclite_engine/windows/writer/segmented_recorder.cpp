#include "segmented_recorder.h"

#include <algorithm>
#include <thread>
#include <utility>

namespace reclite_engine {

std::shared_ptr<SegmentedRecorder> SegmentedRecorder::Create(Settings settings,
                                                             SerialQueue* queue,
                                                             IMFDXGIDeviceManager* manager,
                                                             std::string* error) {
  auto recorder = std::shared_ptr<SegmentedRecorder>(
      new SegmentedRecorder(std::move(settings), queue, manager));
  recorder->writer_ = recorder->MakeWriter(1, 0, error);
  if (!recorder->writer_) {
    return nullptr;
  }
  recorder->audio_target_ = recorder->writer_;
  if (recorder->audio_) {
    std::weak_ptr<SegmentedRecorder> weak = recorder;
    recorder->audio_->set_output([weak](const std::vector<float>& samples, int64_t time) {
      if (auto self = weak.lock()) {
        self->audio_target_->AppendAudio(samples, time);
      }
    });
  }
  return recorder;
}

SegmentedRecorder::SegmentedRecorder(Settings settings, SerialQueue* queue,
                                     IMFDXGIDeviceManager* manager)
    : settings_(std::move(settings)), queue_(queue), manager_(manager) {
  if (settings_.audio_sources > 0) {
    audio_ = std::make_unique<AudioPipeline>(settings_.audio_sources);
  }
}

std::shared_ptr<SegmentWriter> SegmentedRecorder::MakeWriter(int index,
                                                             double starts_in_seconds,
                                                             std::string* error) {
  SegmentWriter::Format format = settings_.format;
  format.with_audio = settings_.audio_sources > 0;
  return std::shared_ptr<SegmentWriter>(
      SegmentWriter::Create(index, settings_.make_path(index, starts_in_seconds), format,
                            manager_.Get(), error)
          .release());
}

std::optional<int64_t> SegmentedRecorder::boundary() const {
  if (!part_start_) {
    return std::nullopt;
  }
  return *part_start_ + settings_.segment_duration;
}

bool SegmentedRecorder::WantsVideo(int64_t host_time) const {
  return !stopped_ && failure_.empty() && !(paused_at_ && host_time >= *paused_at_);
}

void SegmentedRecorder::AppendVideo(ID3D11Texture2D* nv12, int64_t host_time) {
  if (!WantsVideo(host_time)) {
    return;
  }
  const int64_t time = Media(host_time);
  if (const auto edge = boundary(); edge && time >= *edge) {
    Rotate(*edge);
  }
  writer_->AppendVideo(nv12, time);
  if (writer_->failed()) {
    Fail(writer_->failure());
    return;
  }
  if (!origin_ && writer_->has_session()) {
    origin_ = writer_->session_start();
    part_start_ = origin_;
    if (audio_) {
      audio_->Start(*origin_);
    }
    ArmAudioBoundary();
  }
}

void SegmentedRecorder::AppendAudio(int source, const std::vector<float>& samples,
                                    int64_t host_time, int64_t host_now) {
  if (stopped_ || !failure_.empty() || !audio_) {
    return;
  }
  if (paused_at_ && host_time >= *paused_at_) {
    return;
  }
  audio_->Push(source, samples, Media(host_time));
  PumpAudio(host_now);
}

void SegmentedRecorder::Tick(int64_t host_now) {
  if (stopped_ || !failure_.empty() || !part_start_) {
    PublishStats(host_now);
    return;
  }
  PumpAudio(host_now);
  if (const auto edge = boundary()) {
    const int64_t now = Media(paused_at_.value_or(host_now));
    const int64_t until_boundary = *edge - now;
    if (!prepared_ && until_boundary <= kPrewarmLead) {
      std::string ignored;  // Retried on the next tick, and again in Rotate().
      prepared_ = MakeWriter(writer_->index() + 1,
                             std::max(0.0, TicksToSeconds(until_boundary)), &ignored);
    }
    if (!paused_at_ && now >= *edge + kRotationGrace) {
      Rotate(*edge);
    }
  }
  PublishStats(host_now);
}

void SegmentedRecorder::Pause(int64_t host_now) {
  if (!stopped_ && !paused_at_) {
    paused_at_ = host_now;
  }
}

void SegmentedRecorder::Resume(int64_t host_now) {
  if (!paused_at_) {
    return;
  }
  pause_offset_ += std::max<int64_t>(0, host_now - *paused_at_);
  paused_at_.reset();
}

void SegmentedRecorder::Stop(int64_t host_now, StopCallback done) {
  if (stopped_) {
    return;
  }
  stopped_ = true;
  stop_done_ = std::move(done);
  const int64_t end = Media(paused_at_.value_or(host_now));

  if (audio_) {
    audio_->Flush(end);
  }
  if (draining_) {
    FinishPart(std::move(draining_), draining_end_);
    draining_.reset();
  }
  if (prepared_) {
    prepared_->Cancel();
    prepared_.reset();
  }
  FinishPart(writer_, std::max(end, part_start_.value_or(end)));
}

void SegmentedRecorder::PumpAudio(int64_t host_now) {
  if (!audio_) {
    return;
  }
  std::optional<int64_t> ceiling;
  if (paused_at_) {
    ceiling = Media(*paused_at_);
  }
  audio_->Pump(Media(host_now), ceiling);
}

void SegmentedRecorder::Rotate(int64_t time) {
  if (stopped_ || !failure_.empty() || draining_) {
    return;
  }
  std::shared_ptr<SegmentWriter> next = std::move(prepared_);
  prepared_.reset();
  if (!next) {
    std::string error;
    next = MakeWriter(writer_->index() + 1, 0, &error);
    if (!next) {
      Fail(error);
      return;
    }
  }

  std::shared_ptr<SegmentWriter> old = writer_;
  next->StartSession(time);
  if (old->last_frame() != nullptr) {
    next->AppendVideo(old->last_frame(), time);  // The part opens with a picture.
  }
  writer_ = next;
  part_start_ = time;

  const auto emitted = audio_ ? audio_->OutputTime() : std::nullopt;
  if (audio_ && emitted && *emitted < time) {
    draining_ = old;  // Audio before `time` keeps going to the old part.
    draining_end_ = time;
  } else {
    audio_target_ = writer_;
    FinishPart(old, time);
    ArmAudioBoundary();
  }
}

void SegmentedRecorder::ArmAudioBoundary() {
  const auto edge = boundary();
  if (!audio_ || !edge) {
    return;
  }
  std::weak_ptr<SegmentedRecorder> weak = weak_from_this();
  audio_->SetBoundary(*edge, [weak](int64_t) {
    if (auto self = weak.lock()) {
      self->AudioReachedBoundary();
    }
  });
}

void SegmentedRecorder::AudioReachedBoundary() {
  if (draining_) {
    audio_target_ = writer_;
    FinishPart(std::move(draining_), draining_end_);
    draining_.reset();
    ArmAudioBoundary();
  } else if (const auto edge = boundary()) {
    Rotate(*edge);
  }
}

void SegmentedRecorder::FinishPart(std::shared_ptr<SegmentWriter> part, int64_t end) {
  if (!part) {
    return;
  }
  ++pending_finishes_;
  Part info;
  info.index = part->index();
  info.path = part->final_path();
  info.duration = part->DurationUntil(end);
  const int dropped = part->dropped_frames();
  std::weak_ptr<SegmentedRecorder> weak = weak_from_this();
  SerialQueue* queue = queue_;

  // Finalize blocks (it flushes the encoder), so it never runs on the recording queue.
  std::thread([weak, queue, part, end, info, dropped]() mutable {
    ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    std::string error;
    const bool ok = part->Finish(end, &error);
    info.bytes = part->BytesOnDisk();
    part.reset();
    ::CoUninitialize();
    queue->Post([weak, ok, info, dropped, error] {
      if (auto self = weak.lock()) {
        self->OnPartFinished(ok, info, dropped, error);
      }
    });
  }).detach();
}

void SegmentedRecorder::OnPartFinished(bool ok, Part part, int dropped,
                                       const std::string& error) {
  --pending_finishes_;
  if (ok) {
    parts_.push_back(part);
    completed_bytes_ += part.bytes;
    completed_drops_ += dropped;
    if (on_part_finished) {
      on_part_finished(part);
    }
  } else {
    Fail(error);
  }
  if (stopped_ && pending_finishes_ == 0 && stop_done_) {
    std::sort(parts_.begin(), parts_.end(),
              [](const Part& a, const Part& b) { return a.index < b.index; });
    auto done = std::move(stop_done_);
    stop_done_ = nullptr;
    done(parts_, failure_);
  }
}

void SegmentedRecorder::Fail(const std::string& error) {
  if (!failure_.empty()) {
    return;
  }
  failure_ = error.empty() ? "Writing the video failed." : error;
  if (on_failure && !stopped_) {
    on_failure(failure_);
  }
}

void SegmentedRecorder::PublishStats(int64_t host_now) {
  Stats stats;
  if (origin_) {
    stats.elapsed = std::max<int64_t>(0, Media(paused_at_.value_or(host_now)) - *origin_);
  }
  stats.part_index = writer_ ? writer_->index() : 1;
  stats.bytes_written = completed_bytes_ + (writer_ ? writer_->BytesOnDisk() : 0) +
                        (draining_ ? draining_->BytesOnDisk() : 0);
  stats.dropped_frames = completed_drops_ + (writer_ ? writer_->dropped_frames() : 0);
  stats.failure = failure_;
  std::lock_guard<std::mutex> lock(stats_mutex_);
  stats_ = stats;
}

SegmentedRecorder::Stats SegmentedRecorder::Snapshot() const {
  std::lock_guard<std::mutex> lock(stats_mutex_);
  return stats_;
}

}  // namespace reclite_engine
