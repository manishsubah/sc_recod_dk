#include "reclite_engine_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <memory>

#include "engine/capabilities_probe.h"
#include "storage/disk_space_probe.h"

namespace reclite_engine {
namespace {

// Recording on Windows (WGC + Media Foundation) lands in Phase 2.
FlutterError Unsupported() {
  return FlutterError("unsupported",
                      "Recording on Windows is not available yet.");
}

}  // namespace

void RecliteEnginePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<RecliteEnginePlugin>();
  EngineHostApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

RecliteEnginePlugin::RecliteEnginePlugin() = default;

RecliteEnginePlugin::~RecliteEnginePlugin() = default;

ErrorOr<EngineCapabilities> RecliteEnginePlugin::GetCapabilities() {
  return QueryCapabilities();
}

ErrorOr<DiskSpace> RecliteEnginePlugin::GetDiskSpace(const std::string& path) {
  return QueryDiskSpace(path);
}

// Windows Graphics Capture needs no user permission.
ErrorOr<bool> RecliteEnginePlugin::HasScreenCapturePermission() { return true; }

ErrorOr<bool> RecliteEnginePlugin::RequestScreenCapturePermission() {
  return true;
}

std::optional<FlutterError> RecliteEnginePlugin::OpenScreenCaptureSettings() {
  return std::nullopt;
}

// Desktop microphone access is a Windows privacy toggle; checked when capture starts (Phase 2).
ErrorOr<bool> RecliteEnginePlugin::HasMicrophonePermission() { return true; }

void RecliteEnginePlugin::RequestMicrophonePermission(
    std::function<void(ErrorOr<bool> reply)> result) {
  result(true);
}

std::optional<FlutterError> RecliteEnginePlugin::OpenMicrophoneSettings() {
  ::ShellExecuteW(nullptr, L"open", L"ms-settings:privacy-microphone", nullptr,
                  nullptr, SW_SHOWNORMAL);
  return std::nullopt;
}

void RecliteEnginePlugin::ListDisplays(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  result(Unsupported());
}

void RecliteEnginePlugin::StartRecording(
    const EngineRecordingRequest& request,
    std::function<void(ErrorOr<EngineRecordingSession> reply)> result) {
  result(Unsupported());
}

std::optional<FlutterError> RecliteEnginePlugin::PauseRecording() {
  return FlutterError("not_recording", "No recording is running.");
}

std::optional<FlutterError> RecliteEnginePlugin::ResumeRecording() {
  return FlutterError("not_recording", "No recording is running.");
}

// Nothing to recover until Windows can record (Phase 2).
void RecliteEnginePlugin::RecoverSessions(
    const std::string& output_directory,
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  result(flutter::EncodableList());
}

void RecliteEnginePlugin::StopRecording(
    std::function<void(ErrorOr<EngineRecordingResult> reply)> result) {
  result(FlutterError("not_recording", "No recording is running."));
}

std::optional<FlutterError> RecliteEnginePlugin::RevealInFileManager(
    const std::string& path) {
  const std::wstring wide = Utf8ToWide(path);
  if (wide.empty() ||
      ::GetFileAttributesW(wide.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return FlutterError("invalid_path", "Path does not exist: " + path);
  }
  const std::wstring args = L"/select,\"" + wide + L"\"";
  ::ShellExecuteW(nullptr, L"open", L"explorer.exe", args.c_str(), nullptr,
                  SW_SHOWNORMAL);
  return std::nullopt;
}

void RecliteEnginePlugin::SelectArea(
    int64_t display_id,
    std::function<void(ErrorOr<std::optional<EngineCaptureArea>> reply)>
        result) {
  result(Unsupported());
}

}  // namespace reclite_engine
