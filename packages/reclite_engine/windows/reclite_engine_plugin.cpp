#include "reclite_engine_plugin.h"

#include "core/win.h"

#include <shellapi.h>

#include <memory>

#include "audio/wasapi_source.h"
#include "core/strings.h"
#include "engine/capabilities_probe.h"
#include "storage/disk_space_probe.h"

namespace reclite_engine {

void RecliteEnginePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<RecliteEnginePlugin>(registrar);
  EngineHostApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

RecliteEnginePlugin::RecliteEnginePlugin(flutter::PluginRegistrarWindows* registrar)
    : engine_(std::make_unique<RecordingEngine>(registrar)),
      events_(std::make_unique<EngineEventsApi>(registrar->messenger())) {
  shortcuts_ = std::make_unique<GlobalShortcuts>([this](int index) {
    events_->OnShortcut(index, [] {}, [](const FlutterError&) {});
  });
  window_ = std::make_unique<WindowController>(registrar);
  tray_ = std::make_unique<TrayIcon>([this](EngineTrayCommand command) {
    if (command == EngineTrayCommand::kShowWindow) {
      window_->BringToFront();
    }
    events_->OnTrayCommand(command, [] {}, [](const FlutterError&) {});
  });
}

RecliteEnginePlugin::~RecliteEnginePlugin() = default;

ErrorOr<EngineCapabilities> RecliteEnginePlugin::GetCapabilities() {
  return QueryCapabilities();
}

ErrorOr<DiskSpace> RecliteEnginePlugin::GetDiskSpace(const std::string& path) {
  return QueryDiskSpace(path);
}

// Windows Graphics Capture needs no user permission.
ErrorOr<bool> RecliteEnginePlugin::HasScreenCapturePermission() { return true; }

ErrorOr<bool> RecliteEnginePlugin::RequestScreenCapturePermission() { return true; }

std::optional<FlutterError> RecliteEnginePlugin::OpenScreenCaptureSettings() {
  return std::nullopt;
}

// Desktop apps can't prompt for the microphone on Windows; the privacy switch decides.
ErrorOr<bool> RecliteEnginePlugin::HasMicrophonePermission() {
  return WasapiSource::MicrophoneAccessible();
}

void RecliteEnginePlugin::RequestMicrophonePermission(
    std::function<void(ErrorOr<bool> reply)> result) {
  result(WasapiSource::MicrophoneAccessible());
}

std::optional<FlutterError> RecliteEnginePlugin::OpenMicrophoneSettings() {
  ::ShellExecuteW(nullptr, L"open", L"ms-settings:privacy-microphone", nullptr, nullptr,
                  SW_SHOWNORMAL);
  return std::nullopt;
}

void RecliteEnginePlugin::ListDisplays(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  result(engine_->ListDisplays());
}

void RecliteEnginePlugin::ListWindows(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  result(engine_->ListWindows());
}

void RecliteEnginePlugin::StartRecording(
    const EngineRecordingRequest& request,
    std::function<void(ErrorOr<EngineRecordingSession> reply)> result) {
  engine_->Start(request, std::move(result));
}

std::optional<FlutterError> RecliteEnginePlugin::PauseRecording() {
  return engine_->Pause();
}

std::optional<FlutterError> RecliteEnginePlugin::ResumeRecording() {
  return engine_->Resume();
}

void RecliteEnginePlugin::StopRecording(
    std::function<void(ErrorOr<EngineRecordingResult> reply)> result) {
  engine_->Stop(std::move(result));
}

void RecliteEnginePlugin::RecoverSessions(
    const std::string& output_directory,
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  engine_->RecoverSessions(output_directory, std::move(result));
}

std::optional<FlutterError> RecliteEnginePlugin::RevealInFileManager(
    const std::string& path) {
  const std::wstring wide = Utf8ToWide(path);
  if (wide.empty() || ::GetFileAttributesW(wide.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return FlutterError("invalid_path", "Path does not exist: " + path);
  }
  const std::wstring args = L"/select,\"" + wide + L"\"";
  ::ShellExecuteW(nullptr, L"open", L"explorer.exe", args.c_str(), nullptr, SW_SHOWNORMAL);
  return std::nullopt;
}

std::optional<FlutterError> RecliteEnginePlugin::OpenPath(const std::string& path) {
  const std::wstring wide = Utf8ToWide(path);
  if (wide.empty() || ::GetFileAttributesW(wide.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return FlutterError("invalid_path", "Path does not exist: " + path);
  }
  const auto status = reinterpret_cast<INT_PTR>(
      ::ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
  if (status <= 32) {  // ShellExecute reports failure as a value of 32 or less.
    return FlutterError("open_failed", "No app could open " + path);
  }
  return std::nullopt;
}

std::optional<FlutterError> RecliteEnginePlugin::MoveToTrash(const std::string& path) {
  const std::wstring wide = Utf8ToWide(path);
  if (wide.empty() || ::GetFileAttributesW(wide.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return FlutterError("invalid_path", "Path does not exist: " + path);
  }
  std::wstring from = wide;
  from.push_back(L'\0');  // pFrom is a list ending in two nulls.
  SHFILEOPSTRUCTW operation{};
  operation.wFunc = FO_DELETE;
  operation.pFrom = from.c_str();
  operation.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT;
  if (::SHFileOperationW(&operation) != 0 || operation.fAnyOperationsAborted) {
    return FlutterError("trash_failed", "Could not move to the Recycle Bin: " + path);
  }
  return std::nullopt;
}

ErrorOr<flutter::EncodableList> RecliteEnginePlugin::SetGlobalShortcuts(
    const flutter::EncodableList& shortcuts) {
  std::vector<GlobalShortcuts::Shortcut> keys;
  for (const auto& value : shortcuts) {
    const auto& s =
        std::any_cast<const EngineShortcut&>(std::get<flutter::CustomEncodableValue>(value));
    keys.push_back({s.key(), s.control(), s.alt(), s.shift(), s.meta()});
  }
  flutter::EncodableList failed;
  for (const int index : shortcuts_->Set(keys)) {
    failed.push_back(flutter::EncodableValue(static_cast<int64_t>(index)));
  }
  return failed;
}

std::optional<FlutterError> RecliteEnginePlugin::SetMiniWindow(bool mini) {
  window_->SetMini(mini);
  return std::nullopt;
}

std::optional<FlutterError> RecliteEnginePlugin::StartWindowDrag() {
  window_->StartDrag();
  return std::nullopt;
}

std::optional<FlutterError> RecliteEnginePlugin::SetTrayState(const EngineTrayState& state) {
  tray_->SetState(state);
  return std::nullopt;
}

void RecliteEnginePlugin::SelectArea(
    int64_t display_id,
    std::function<void(ErrorOr<std::optional<EngineCaptureArea>> reply)> result) {
  engine_->SelectArea(display_id, std::move(result));
}

}  // namespace reclite_engine
