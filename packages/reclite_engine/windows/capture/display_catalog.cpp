#include "display_catalog.h"

#include <algorithm>
#include <cwchar>
#include <cwctype>
#include <map>

#include "../core/strings.h"

namespace reclite_engine {
namespace {

// \\.\DISPLAY3 -> 3
int64_t DisplayNumber(const wchar_t* device) {
  const std::wstring name(device);
  size_t i = name.size();
  while (i > 0 && std::iswdigit(name[i - 1])) {
    --i;
  }
  return i < name.size() ? std::wcstoll(name.c_str() + i, nullptr, 10) : 0;
}

bool IsBuiltIn(DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY technology) {
  return technology == DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INTERNAL ||
         technology == DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED ||
         technology == DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EMBEDDED;
}

// GDI device name -> monitor's friendly name (e.g. "DELL U2720Q"); laptop panels
// usually report none, so they are named "Built-in Display".
std::map<std::wstring, std::wstring> FriendlyNames() {
  std::map<std::wstring, std::wstring> names;
  UINT32 path_count = 0;
  UINT32 mode_count = 0;
  if (::GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &path_count, &mode_count) !=
      ERROR_SUCCESS) {
    return names;
  }
  std::vector<DISPLAYCONFIG_PATH_INFO> paths(path_count);
  std::vector<DISPLAYCONFIG_MODE_INFO> modes(mode_count);
  if (::QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &path_count, paths.data(), &mode_count,
                           modes.data(), nullptr) != ERROR_SUCCESS) {
    return names;
  }
  for (UINT32 i = 0; i < path_count; ++i) {
    DISPLAYCONFIG_SOURCE_DEVICE_NAME source{};
    source.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
    source.header.size = sizeof(source);
    source.header.adapterId = paths[i].sourceInfo.adapterId;
    source.header.id = paths[i].sourceInfo.id;

    DISPLAYCONFIG_TARGET_DEVICE_NAME target{};
    target.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
    target.header.size = sizeof(target);
    target.header.adapterId = paths[i].targetInfo.adapterId;
    target.header.id = paths[i].targetInfo.id;

    if (::DisplayConfigGetDeviceInfo(&source.header) != ERROR_SUCCESS ||
        ::DisplayConfigGetDeviceInfo(&target.header) != ERROR_SUCCESS) {
      continue;
    }
    if (IsBuiltIn(paths[i].targetInfo.outputTechnology)) {
      names[source.viewGdiDeviceName] = L"Built-in Display";
    } else if (target.monitorFriendlyDeviceName[0] != L'\0') {
      names[source.viewGdiDeviceName] = target.monitorFriendlyDeviceName;
    }
  }
  return names;
}

BOOL CALLBACK CollectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* displays = reinterpret_cast<std::vector<DisplayInfo>*>(data);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (::GetMonitorInfoW(monitor, &info)) {
    DisplayInfo display;
    display.id = DisplayNumber(info.szDevice);
    display.monitor = monitor;
    display.bounds = info.rcMonitor;
    display.is_primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
    display.name = WideToUtf8(info.szDevice);
    displays->push_back(display);
  }
  return TRUE;
}

}  // namespace

std::vector<DisplayInfo> ListDisplays() {
  std::vector<DisplayInfo> displays;
  ::EnumDisplayMonitors(nullptr, nullptr, &CollectMonitor,
                        reinterpret_cast<LPARAM>(&displays));

  const auto friendly = FriendlyNames();
  for (auto& display : displays) {
    MONITORINFOEXW info{};
    info.cbSize = sizeof(info);
    ::GetMonitorInfoW(display.monitor, &info);
    const auto name = friendly.find(info.szDevice);
    display.name = name != friendly.end()
                       ? WideToUtf8(name->second)
                       : "Display " + std::to_string(display.id);
  }
  std::stable_sort(displays.begin(), displays.end(),
                   [](const DisplayInfo& a, const DisplayInfo& b) {
                     return a.is_primary && !b.is_primary;
                   });
  return displays;
}

std::optional<DisplayInfo> FindDisplay(int64_t id) {
  for (const auto& display : ListDisplays()) {
    if (display.id == id) {
      return display;
    }
  }
  return std::nullopt;
}

}  // namespace reclite_engine
