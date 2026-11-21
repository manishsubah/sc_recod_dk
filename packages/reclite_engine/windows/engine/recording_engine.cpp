#include "recording_engine.h"

#include <mfapi.h>

#include <algorithm>
#include <cmath>
#include <future>
#include <system_error>
#include <utility>

#include "../capture/display_catalog.h"
#include "../capture/window_catalog.h"
#include "../core/clock.h"
#include "../core/strings.h"
#include "../storage/disk_guard.h"
#include "../storage/disk_space_probe.h"
#include "../storage/session_storage.h"

namespace reclite_engine {
namespace {

namespace fs = std::filesystem;

constexpr UINT_PTR kStatusTimer = 1;
constexpr UINT_PTR kLevelsTimer = 2;
constexpr int64_t kMinimumSegmentSeconds = 5;
// Converted frames waiting for the encoder; beyond this, frames are dropped (bounded memory).
constexpr int kMaxFramesInFlight = 6;

FlutterError Error(const std::string& code, const std::string& message) {
  return FlutterError(code, message);
}

int Even(int value) { return value - value % 2; }

// Scales down to `max_height` keeping aspect ratio; H.264 needs even sizes.
std::pair<int, int> FitOutput(int width, int height, int max_height) {
  if (max_height <= 0 || height <= max_height) {
    return {Even(width), Even(height)};
  }
  const double scaled = static_cast<double>(width) * max_height / height;
  return {Even(static_cast<int>(std::lround(scaled))), Even(max_height)};
}

void NotifyIgnore() {}
void NotifyIgnoreError(const FlutterError&) {}

}  // namespace

RecordingEngine::RecordingEngine(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      events_(std::make_unique<EngineEventsApi>(registrar->messenger())) {
  queue_ = std::make_unique<SerialQueue>(
      [] {
        ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        ::MFStartup(MF_VERSION, MFSTARTUP_FULL);
      },
      [] {
        ::MFShutdown();
        ::CoUninitialize();
      });
}

RecordingEngine::~RecordingEngine() {
  *alive_ = false;
  dispatcher_.StopTimer(kStatusTimer);
  dispatcher_.StopTimer(kLevelsTimer);
  TearDownCapture();
  queue_.reset();  // Joins the recording thread.
  session_.reset();
}

bool RecordingEngine::IsActive() const {
  return phase_ == EngineRecordingPhase::kRecording || phase_ == EngineRecordingPhase::kPaused;
}

HWND RecordingEngine::RootWindow() const {
  flutter::FlutterView* view = registrar_->GetView();
  return view != nullptr ? ::GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
}

ErrorOr<flutter::EncodableList> RecordingEngine::ListDisplays() {
  if (!ScreenCapture::IsSupported()) {
    return Error("unsupported", "This version of Windows can't record the screen.");
  }
  flutter::EncodableList list;
  for (const auto& display : ::reclite_engine::ListDisplays()) {
    list.push_back(flutter::CustomEncodableValue(
        EngineDisplay(display.id, display.name, display.width(), display.height(),
                      display.is_primary)));
  }
  return list;
}

ErrorOr<flutter::EncodableList> RecordingEngine::ListWindows() {
  if (!ScreenCapture::IsSupported()) {
    return Error("unsupported", "This version of Windows can't record the screen.");
  }
  flutter::EncodableList list;
  for (const auto& window : ListCaptureWindows(::GetCurrentProcessId())) {
    list.push_back(flutter::CustomEncodableValue(EngineWindow(
        static_cast<int64_t>(reinterpret_cast<intptr_t>(window.hwnd)), window.title,
        window.app_name, window.width, window.height)));
  }
  return list;
}

void RecordingEngine::SelectArea(
    int64_t display_id,
    std::function<void(ErrorOr<std::optional<EngineCaptureArea>>)> result) {
  if (phase_ != EngineRecordingPhase::kIdle) {
    result(Error("already_recording", "A recording is already running."));
    return;
  }
  const auto display = FindDisplay(display_id);
  if (!display) {
    result(Error("display_not_found", "The selected display is not available."));
    return;
  }
  selector_.Select(display->monitor, [result](std::optional<RECT> rect) {
    if (!rect) {
      result(std::optional<EngineCaptureArea>());
      return;
    }
    result(std::optional<EngineCaptureArea>(EngineCaptureArea(
        rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top)));
  });
}

void RecordingEngine::Start(const EngineRecordingRequest& request,
                            std::function<void(ErrorOr<EngineRecordingSession>)> result) {
  if (phase_ != EngineRecordingPhase::kIdle) {
    result(Error("already_recording", "A recording is already running."));
    return;
  }
  if (!ScreenCapture::IsSupported()) {
    result(Error("unsupported", "This version of Windows can't record the screen."));
    return;
  }
  // A window recording ignores the display and area.
  const int64_t* window_id = request.window_id();
  const HWND window =
      window_id != nullptr ? reinterpret_cast<HWND>(static_cast<intptr_t>(*window_id)) : nullptr;
  std::optional<DisplayInfo> display;
  if (window != nullptr) {
    if (!IsRecordableWindow(window)) {
      result(Error("window_not_found",
                   "The selected window was closed or minimized. Pick it again."));
      return;
    }
  } else {
    display = FindDisplay(request.display_id());
    if (!display) {
      result(Error("display_not_found", "The selected display is not available."));
      return;
    }
  }
  if (request.capture_microphone() && !WasapiSource::MicrophoneAccessible()) {
    result(Error("microphone_permission_denied",
                 "Windows blocks microphone access. Turn it on in Settings > Privacy > "
                 "Microphone, or record without the microphone."));
    return;
  }

  // The area is in physical pixels relative to the monitor (what the overlay returns).
  RECT source{0, 0, display ? display->width() : 0, display ? display->height() : 0};
  const EngineCaptureArea* area = window != nullptr ? nullptr : request.area();
  if (area != nullptr) {
    RECT wanted{static_cast<LONG>(area->x()), static_cast<LONG>(area->y()),
                static_cast<LONG>(area->x() + area->width()),
                static_cast<LONG>(area->y() + area->height())};
    RECT clipped{};
    if (!::IntersectRect(&clipped, &wanted, &source) ||
        clipped.right - clipped.left < AreaSelector::kMinimumSize ||
        clipped.bottom - clipped.top < AreaSelector::kMinimumSize) {
      result(Error("invalid_area", "The selected area is outside the screen or too small."));
      return;
    }
    source = clipped;
  }

  SetPhase(EngineRecordingPhase::kStarting);
  auto session = std::make_unique<Session>();
  std::string error;
  const auto fail = [&](const std::string& code, const std::string& message) {
    if (session->capture) session->capture->Stop();
    for (auto& source_audio : session->audio) source_audio->Stop();
    if (!session->directory.empty()) {
      std::error_code ec;
      fs::remove(session->directory / SessionManifest::kFileName, ec);
      fs::remove(session->directory, ec);  // Only succeeds when the folder is empty.
    }
    SetPhase(EngineRecordingPhase::kIdle);
    result(Error(code, message));
  };

  const std::wstring stamp = session_naming::Stamp();
  const auto directory = session_naming::CreateSessionDirectory(
      fs::path(Utf8ToWide(request.output_directory())), stamp, &error);
  if (!directory) {
    fail("writer_failed", error);
    return;
  }
  session->directory = *directory;

  session->gpu = GpuDevice::Create(&error);
  if (!session->gpu) {
    fail("capture_failed", error);
    return;
  }
  session->capture =
      window != nullptr
          ? ScreenCapture::CreateForWindow(window, session->gpu->device(), &error)
          : ScreenCapture::Create(display->monitor, session->gpu->device(), &error);
  if (!session->capture) {
    fail("capture_failed", error);
    return;
  }
  if (window != nullptr) {
    source = {0, 0, session->capture->width(), session->capture->height()};
  }

  const int source_width = source.right - source.left;
  const int source_height = source.bottom - source.top;
  const auto [width, height] =
      FitOutput(source_width, source_height, static_cast<int>(request.max_height()));
  const int fps = static_cast<int>(std::clamp<int64_t>(request.frames_per_second(), 1, 60));

  session->converter = std::shared_ptr<FrameConverter>(
      FrameConverter::Create(session->gpu->device(),
                             static_cast<UINT>(session->capture->width()),
                             static_cast<UINT>(session->capture->height()), source,
                             static_cast<UINT>(width), static_cast<UINT>(height), &error)
          .release());
  if (!session->converter) {
    fail("capture_failed", error);
    return;
  }

  if (request.capture_system_audio()) session->system_index = 0;
  if (request.capture_microphone()) {
    session->microphone_index = session->system_index + 1;
  }
  const int audio_sources = (session->system_index >= 0) + (session->microphone_index >= 0);

  SegmentedRecorder::Settings settings;
  settings.segment_duration =
      std::max(request.segment_seconds(), kMinimumSegmentSeconds) * kTicksPerSecond;
  settings.format.width = width;
  settings.format.height = height;
  settings.format.frames_per_second = fps;
  settings.audio_sources = audio_sources;
  const fs::path session_directory = session->directory;
  settings.make_path = [session_directory, stamp](int index, double starts_in_seconds) {
    return session_directory /
           session_naming::SegmentFileName(
               index == 1 ? stamp : session_naming::Stamp(starts_in_seconds), index);
  };

  // Writers are created and used on the recording queue (MTA + Media Foundation).
  {
    auto created = std::make_shared<std::promise<std::pair<std::shared_ptr<SegmentedRecorder>, std::string>>>();
    auto future = created->get_future();
    IMFDXGIDeviceManager* manager = session->gpu->manager();
    SerialQueue* queue = queue_.get();
    queue_->Post([created, settings, manager, queue] {
      std::string create_error;
      auto recorder = SegmentedRecorder::Create(settings, queue, manager, &create_error);
      created->set_value({recorder, create_error});
    });
    auto outcome = future.get();
    session->recorder = outcome.first;
    if (!session->recorder) {
      fail("writer_failed", outcome.second);
      return;
    }
  }

  std::weak_ptr<bool> alive = alive_;
  session->recorder->on_part_finished = [this, alive](const SegmentedRecorder::Part& part) {
    dispatcher_.Post([this, alive, part] {
      if (!alive.expired()) RecordPart(part);
    });
  };
  session->recorder->on_failure = [this, alive](const std::string& message) {
    dispatcher_.Post([this, alive, message] {
      if (!alive.expired()) {
        EndAfterFailure("writer_failed",
                        "Recording stopped: " + message + " Finished parts were saved.");
      }
    });
  };

  // session.json: written now, updated as each part closes.
  SessionManifest& manifest = session->manifest;
  manifest.session_id = WideToUtf8(stamp);
  manifest.started_at = session_naming::UtcNow();
  manifest.status = "recording";
  manifest.source_type = window != nullptr ? "window" : area != nullptr ? "area" : "display";
  manifest.source_name = window != nullptr ? WindowTitle(window) : display->name;
  if (area != nullptr) {
    manifest.area = {static_cast<double>(source.left), static_cast<double>(source.top),
                     static_cast<double>(source_width), static_cast<double>(source_height)};
  }
  manifest.system_audio = session->system_index >= 0;
  manifest.microphone = session->microphone_index >= 0;
  manifest.width = width;
  manifest.height = height;
  manifest.fps = fps;
  manifest.segment_seconds = static_cast<int>(settings.segment_duration / kTicksPerSecond);
  WriteManifest(manifest, session->directory);

  // Audio sources feed the recorder through the queue.
  std::shared_ptr<SegmentedRecorder> recorder = session->recorder;
  SerialQueue* queue = queue_.get();
  const auto add_audio = [&](WasapiSource::Kind kind, int index) -> bool {
    auto source_audio = std::make_unique<WasapiSource>(
        kind, [recorder, queue, index](std::vector<float>&& samples, int64_t time) {
          auto shared = std::make_shared<std::vector<float>>(std::move(samples));
          queue->Post([recorder, index, shared, time] {
            recorder->AppendAudio(index, *shared, time, HostNow());
          });
        });
    if (!source_audio->Start(&error)) {
      return false;
    }
    session->audio.push_back(std::move(source_audio));
    return true;
  };
  if (session->system_index >= 0 &&
      !add_audio(WasapiSource::Kind::kSystemLoopback, session->system_index)) {
    fail("capture_failed", error);
    return;
  }
  if (session->microphone_index >= 0 &&
      !add_audio(WasapiSource::Kind::kMicrophone, session->microphone_index)) {
    fail("microphone_permission_denied", error);
    return;
  }

  if (window != nullptr) {
    session->capture->SetClosedHandler([this, alive] {
      dispatcher_.Post([this, alive] {
        if (!alive.expired()) {
          EndAfterFailure("window_closed",
                          "The recorded window was closed. Everything until then was saved.");
        }
      });
    });
  }

  // Frames: converted on the capture thread (GPU), encoded on the queue.
  session->frames_in_flight = std::make_shared<std::atomic<int>>(0);
  auto converter = session->converter;
  auto in_flight = session->frames_in_flight;
  const bool started = session->capture->Start(
      request.show_cursor(),
      [converter, recorder, queue, in_flight](ID3D11Texture2D* frame, int64_t time) {
        if (in_flight->load() >= kMaxFramesInFlight) {
          return;  // The encoder is behind: drop rather than queue.
        }
        ComPtr<ID3D11Texture2D> nv12 = converter->Convert(frame);
        if (!nv12) {
          return;
        }
        ++*in_flight;
        queue->Post([recorder, nv12, time, in_flight] {
          recorder->AppendVideo(nv12.Get(), time);
          --*in_flight;
        });
      },
      &error);
  if (!started) {
    fail("capture_failed", error);
    return;
  }

  // RecLite's own windows never appear in the video.
  session->excluded_window = RootWindow();
  if (session->excluded_window != nullptr) {
    ::SetWindowDisplayAffinity(session->excluded_window, WDA_EXCLUDEFROMCAPTURE);
  }
  if (area != nullptr) {
    highlight_.Show(display->monitor, source);
  }
  ::SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED);

  queue_->SetTicker(std::chrono::milliseconds(100),
                    [recorder] { recorder->Tick(HostNow()); });
  dispatcher_.StartTimer(kStatusTimer, 1000, [this] { Tick(); });
  if (audio_sources > 0) {
    dispatcher_.StartTimer(kLevelsTimer, 66, [this] { SendLevels(); });
  }

  const std::string directory_utf8 = WideToUtf8(session->directory.wstring());
  session_ = std::move(session);
  SetPhase(EngineRecordingPhase::kRecording);
  result(EngineRecordingSession(directory_utf8, width, height));
}

std::optional<FlutterError> RecordingEngine::Pause() {
  if (phase_ != EngineRecordingPhase::kRecording || !session_) {
    return Error("not_recording", "No recording is running.");
  }
  const int64_t now = HostNow();
  auto recorder = session_->recorder;
  queue_->Post([recorder, now] { recorder->Pause(now); });
  SetPhase(EngineRecordingPhase::kPaused);
  return std::nullopt;
}

std::optional<FlutterError> RecordingEngine::Resume() {
  if (phase_ != EngineRecordingPhase::kPaused || !session_) {
    return Error("not_recording", "No recording is running.");
  }
  const int64_t now = HostNow();
  auto recorder = session_->recorder;
  queue_->Post([recorder, now] { recorder->Resume(now); });
  SetPhase(EngineRecordingPhase::kRecording);
  return std::nullopt;
}

void RecordingEngine::Stop(StopResult result) {
  if (!IsActive() || !session_) {
    result(Error("not_recording", "No recording is running."));
    return;
  }
  Finish(std::move(result));
}

void RecordingEngine::TearDownCapture() {
  highlight_.Hide();
  if (!session_) {
    return;
  }
  if (session_->capture) {
    session_->capture->Stop();
  }
  for (auto& source_audio : session_->audio) {
    source_audio->Stop();
  }
  if (session_->excluded_window != nullptr) {
    ::SetWindowDisplayAffinity(session_->excluded_window, WDA_NONE);
    session_->excluded_window = nullptr;
  }
  ::SetThreadExecutionState(ES_CONTINUOUS);
}

void RecordingEngine::Finish(StopResult result) {
  SetPhase(EngineRecordingPhase::kStopping);
  dispatcher_.StopTimer(kStatusTimer);
  dispatcher_.StopTimer(kLevelsTimer);
  events_->OnAudioLevels(EngineAudioLevels(0, 0), NotifyIgnore, NotifyIgnoreError);
  TearDownCapture();
  queue_->ClearTicker();

  const int64_t now = HostNow();
  auto recorder = session_->recorder;
  std::weak_ptr<bool> alive = alive_;
  queue_->Post([this, alive, recorder, now, result] {
    recorder->Stop(now, [this, alive, result](std::vector<SegmentedRecorder::Part> parts,
                                              std::string error) {
      dispatcher_.Post([this, alive, result, parts = std::move(parts), error] {
        if (!alive.expired()) OnStopped(parts, error, result);
      });
    });
  });
}

void RecordingEngine::OnStopped(std::vector<SegmentedRecorder::Part> parts, std::string error,
                                StopResult result) {
  for (const auto& part : parts) {
    RecordPart(part);
  }
  Session& session = *session_;
  session.manifest.status = parts.empty() ? "failed" : "completed";
  session.manifest.ended_at = session_naming::UtcNow();
  WriteManifest(session.manifest, session.directory);

  const std::string directory = WideToUtf8(session.directory.wstring());
  flutter::EncodableList files;
  int64_t duration_ms = 0;
  int64_t bytes = 0;
  for (const auto& part : parts) {
    files.push_back(flutter::EncodableValue(WideToUtf8(part.path.wstring())));
    duration_ms += part.duration / kTicksPerMillisecond;
    bytes += part.bytes;
  }
  session_.reset();
  SetPhase(EngineRecordingPhase::kIdle);

  if (!result) {
    return;
  }
  if (parts.empty()) {
    result(Error("writer_failed",
                 error.empty() ? "The video file could not be written." : error));
    return;
  }
  result(EngineRecordingResult(directory, files, duration_ms, bytes));
}

void RecordingEngine::EndAfterFailure(const std::string& code, const std::string& message) {
  if (!IsActive() || !session_) {
    return;
  }
  std::weak_ptr<bool> alive = alive_;
  Finish([this, alive, code, message](ErrorOr<EngineRecordingResult>) {
    if (!alive.expired()) SendError(code, message, true);
  });
}

void RecordingEngine::RecordPart(const SegmentedRecorder::Part& part) {
  if (!session_) {
    return;
  }
  SessionManifest::Segment segment;
  segment.index = part.index;
  segment.file = WideToUtf8(part.path.filename().wstring());
  segment.duration_ms = part.duration / kTicksPerMillisecond;
  segment.bytes = part.bytes;
  const size_t before = session_->manifest.segments.size();
  session_->manifest.AddSegment(segment);
  if (session_->manifest.segments.size() != before) {
    WriteManifest(session_->manifest, session_->directory);
  }
}

void RecordingEngine::Tick() {
  if (!IsActive() || !session_) {
    return;
  }
  const auto stats = session_->recorder->Snapshot();
  SendStatus(&stats);
  if (++session_->ticks % disk_guard::kCheckEverySeconds == 0) {
    CheckDiskSpace(stats);
  }
}

void RecordingEngine::CheckDiskSpace(const SegmentedRecorder::Stats& stats) {
  auto space = QueryDiskSpace(WideToUtf8(session_->directory.wstring()));
  if (space.has_error()) {
    return;
  }
  const int64_t free_bytes = space.value().free_bytes();
  const double seconds = TicksToSeconds(stats.elapsed);
  const double bytes_per_second =
      seconds > 1 ? static_cast<double>(stats.bytes_written) / seconds : 0;
  switch (disk_guard::Check(free_bytes)) {
    case disk_guard::Verdict::kOk:
      session_->low_space_warned = false;
      break;
    case disk_guard::Verdict::kLow:
      if (!session_->low_space_warned) {
        session_->low_space_warned = true;
        SendError("low_disk_space", disk_guard::LowSpaceMessage(free_bytes, bytes_per_second),
                  false);
      }
      break;
    case disk_guard::Verdict::kCritical:
      EndAfterFailure("disk_full",
                      "Recording stopped: the disk is almost full. Your recording was saved.");
      break;
  }
}

void RecordingEngine::SetPhase(EngineRecordingPhase phase) {
  phase_ = phase;
  if (session_ && session_->recorder) {
    const auto stats = session_->recorder->Snapshot();
    SendStatus(&stats);
  } else {
    SendStatus(nullptr);
  }
}

void RecordingEngine::SendStatus(const SegmentedRecorder::Stats* stats) {
  events_->OnStatus(
      EngineRecordingStatus(phase_, stats ? stats->elapsed / kTicksPerMillisecond : 0,
                            stats ? stats->part_index : 1, stats ? stats->bytes_written : 0,
                            stats ? stats->dropped_frames : 0),
      NotifyIgnore, NotifyIgnoreError);
}

void RecordingEngine::SendError(const std::string& code, const std::string& message,
                                bool fatal) {
  events_->OnError(EngineError(code, message, fatal), NotifyIgnore, NotifyIgnoreError);
}

void RecordingEngine::SendLevels() {
  if (!IsActive() || !session_ || !session_->recorder->meter()) {
    return;
  }
  const auto levels = session_->recorder->meter()->TakeLevels();
  const auto level = [&levels](int index) {
    return index >= 0 && static_cast<size_t>(index) < levels.size()
               ? levels[static_cast<size_t>(index)]
               : 0.0;
  };
  events_->OnAudioLevels(
      EngineAudioLevels(level(session_->system_index), level(session_->microphone_index)),
      NotifyIgnore, NotifyIgnoreError);
}

void RecordingEngine::RecoverSessions(
    const std::string& output_directory,
    std::function<void(ErrorOr<flutter::EncodableList>)> result) {
  const fs::path parent(Utf8ToWide(output_directory));
  const fs::path active = session_ ? session_->directory : fs::path();
  std::weak_ptr<bool> alive = alive_;
  queue_->Post([this, alive, parent, active, result] {
    auto recovered = ::reclite_engine::RecoverSessions(parent, active);
    dispatcher_.Post([alive, recovered = std::move(recovered), result] {
      if (alive.expired()) return;
      flutter::EncodableList list;
      for (const auto& session : recovered) {
        flutter::EncodableList files;
        for (const auto& file : session.files) {
          files.push_back(flutter::EncodableValue(WideToUtf8(file.wstring())));
        }
        list.push_back(flutter::CustomEncodableValue(EngineRecoveredSession(
            WideToUtf8(session.directory.wstring()), files, session.duration_ms)));
      }
      result(list);
    });
  });
}

}  // namespace reclite_engine
