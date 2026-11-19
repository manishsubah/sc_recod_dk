#include "capabilities_probe.h"

// clang-format off
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mftransform.h>
// clang-format on

#include <string>

namespace reclite_engine {
namespace {

constexpr char kEngineVersion[] = "0.1.0";

// Windows 10 version 2004 (build 19041): stable Windows Graphics Capture with
// cursor control. See docs/PLAN.md §4.
constexpr DWORD kMinBuild = 19041;
constexpr char kMinimumOsVersion[] = "10.0.19041";

struct OsVersion {
  DWORD major = 0;
  DWORD minor = 0;
  DWORD build = 0;
};

// GetVersionEx lies without an app manifest; RtlGetVersion always reports the
// real version. Loaded dynamically so we do not need to link ntdll.lib.
OsVersion QueryOsVersion() {
  using RtlGetVersionFn = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  RTL_OSVERSIONINFOW info{};
  info.dwOSVersionInfoSize = sizeof(info);

  HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
  if (ntdll != nullptr) {
    auto rtl_get_version = reinterpret_cast<RtlGetVersionFn>(
        ::GetProcAddress(ntdll, "RtlGetVersion"));
    if (rtl_get_version != nullptr && rtl_get_version(&info) == 0) {
      return {info.dwMajorVersion, info.dwMinorVersion, info.dwBuildNumber};
    }
  }
  return {};
}

// True if Media Foundation lists at least one hardware encoder MFT
// (NVENC / QuickSync / AMF) producing `subtype`.
bool HasHardwareEncoder(const GUID& subtype) {
  MFT_REGISTER_TYPE_INFO output_type{MFMediaType_Video, subtype};
  IMFActivate** activates = nullptr;
  UINT32 count = 0;

  HRESULT hr = ::MFTEnumEx(MFT_CATEGORY_VIDEO_ENCODER,
                           MFT_ENUM_FLAG_HARDWARE | MFT_ENUM_FLAG_SORTANDFILTER,
                           nullptr, &output_type, &activates, &count);
  if (FAILED(hr)) {
    return false;
  }
  for (UINT32 i = 0; i < count; ++i) {
    activates[i]->Release();
  }
  ::CoTaskMemFree(activates);
  return count > 0;
}

}  // namespace

EngineCapabilities QueryCapabilities() {
  const OsVersion os = QueryOsVersion();
  const std::string os_version = std::to_string(os.major) + "." +
                                 std::to_string(os.minor) + "." +
                                 std::to_string(os.build);
  const bool meets_minimum =
      os.major > 10 || (os.major == 10 && os.build >= kMinBuild);

  return EngineCapabilities(
      HostPlatform::kWindows, os_version, kMinimumOsVersion, meets_minimum,
      /*supports_recording=*/false,
      /*supports_system_audio=*/meets_minimum,  // WASAPI loopback
      /*supports_microphone_via_screen_capture=*/false,
      HasHardwareEncoder(MFVideoFormat_H264),
      HasHardwareEncoder(MFVideoFormat_HEVC), kEngineVersion);
}

}  // namespace reclite_engine
