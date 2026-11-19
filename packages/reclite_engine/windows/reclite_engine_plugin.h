#ifndef FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_
#define FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <functional>
#include <optional>
#include <string>

#include "messages.g.h"

namespace reclite_engine {

class RecliteEnginePlugin : public flutter::Plugin, public EngineHostApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  RecliteEnginePlugin();
  ~RecliteEnginePlugin() override;

  RecliteEnginePlugin(const RecliteEnginePlugin&) = delete;
  RecliteEnginePlugin& operator=(const RecliteEnginePlugin&) = delete;

  ErrorOr<EngineCapabilities> GetCapabilities() override;
  ErrorOr<DiskSpace> GetDiskSpace(const std::string& path) override;
  ErrorOr<bool> HasScreenCapturePermission() override;
  ErrorOr<bool> RequestScreenCapturePermission() override;
  std::optional<FlutterError> OpenScreenCaptureSettings() override;
  void ListDisplays(
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result) override;
  void StartRecording(
      const EngineRecordingRequest& request,
      std::function<void(ErrorOr<EngineRecordingSession> reply)> result) override;
  void StopRecording(
      std::function<void(ErrorOr<EngineRecordingResult> reply)> result) override;
  std::optional<FlutterError> RevealInFileManager(const std::string& path) override;
  void SelectArea(
      int64_t display_id,
      std::function<void(ErrorOr<std::optional<EngineCaptureArea>> reply)>
          result) override;
};

}  // namespace reclite_engine

#endif  // FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_
