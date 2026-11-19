#ifndef RECLITE_ENGINE_ENGINE_RECORDING_ENGINE_H_
#define RECLITE_ENGINE_ENGINE_RECORDING_ENGINE_H_

#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "../audio/wasapi_source.h"
#include "../capture/frame_converter.h"
#include "../capture/gpu_device.h"
#include "../capture/screen_capture.h"
#include "../core/platform_dispatcher.h"
#include "../core/serial_queue.h"
#include "../messages.g.h"
#include "../storage/session_manifest.h"
#include "../ui/area_windows.h"
#include "../writer/segmented_recorder.h"

namespace reclite_engine {

// Owns the Windows recording lifecycle — the twin of the macOS RecordingEngine.
// Public methods run on the platform thread; frames are converted on the capture
// thread and encoded on the recording queue.
class RecordingEngine {
 public:
  explicit RecordingEngine(flutter::PluginRegistrarWindows* registrar);
  ~RecordingEngine();

  RecordingEngine(const RecordingEngine&) = delete;
  RecordingEngine& operator=(const RecordingEngine&) = delete;

  ErrorOr<flutter::EncodableList> ListDisplays();
  void SelectArea(int64_t display_id,
                  std::function<void(ErrorOr<std::optional<EngineCaptureArea>>)> result);
  void Start(const EngineRecordingRequest& request,
             std::function<void(ErrorOr<EngineRecordingSession>)> result);
  std::optional<FlutterError> Pause();
  std::optional<FlutterError> Resume();
  void Stop(std::function<void(ErrorOr<EngineRecordingResult>)> result);
  void RecoverSessions(const std::string& output_directory,
                       std::function<void(ErrorOr<flutter::EncodableList>)> result);

 private:
  struct Session {
    std::filesystem::path directory;
    SessionManifest manifest;
    std::unique_ptr<GpuDevice> gpu;
    std::unique_ptr<ScreenCapture> capture;
    std::shared_ptr<FrameConverter> converter;
    std::shared_ptr<SegmentedRecorder> recorder;
    std::vector<std::unique_ptr<WasapiSource>> audio;
    int system_index = -1;
    int microphone_index = -1;
    std::shared_ptr<std::atomic<int>> frames_in_flight;
    HWND excluded_window = nullptr;
    bool low_space_warned = false;
    int ticks = 0;
  };

  using StopResult = std::function<void(ErrorOr<EngineRecordingResult>)>;

  bool IsActive() const;
  void SetPhase(EngineRecordingPhase phase);
  void SendStatus(const SegmentedRecorder::Stats* stats);
  void SendError(const std::string& code, const std::string& message, bool fatal);
  void SendLevels();
  void Tick();
  void CheckDiskSpace(const SegmentedRecorder::Stats& stats);
  void RecordPart(const SegmentedRecorder::Part& part);
  void Finish(StopResult result);
  void OnStopped(std::vector<SegmentedRecorder::Part> parts, std::string error,
                 StopResult result);
  void EndAfterFailure(const std::string& code, const std::string& message);
  void TearDownCapture();
  HWND RootWindow() const;

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<EngineEventsApi> events_;
  PlatformDispatcher dispatcher_;
  std::unique_ptr<SerialQueue> queue_;
  EngineRecordingPhase phase_ = EngineRecordingPhase::kIdle;
  std::unique_ptr<Session> session_;
  AreaSelector selector_;
  AreaHighlight highlight_;
  // Cleared on destruction so late callbacks from other threads do nothing.
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_ENGINE_RECORDING_ENGINE_H_
