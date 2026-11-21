#include "window_catalog.h"

#include <dwmapi.h>

#include <filesystem>

#include "../core/strings.h"

namespace reclite_engine {
namespace {

constexpr int kMinimumSize = 64;

bool IsCloaked(HWND hwnd) {
  DWORD cloaked = 0;
  return SUCCEEDED(::DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked))) &&
         cloaked != 0;
}

bool IsShellWindow(HWND hwnd) {
  wchar_t name[64] = {};
  ::GetClassNameW(hwnd, name, 64);
  const std::wstring cls(name);
  return cls == L"Progman" || cls == L"WorkerW" || cls == L"Shell_TrayWnd" ||
         cls == L"Shell_SecondaryTrayWnd";
}

RECT VisibleBounds(HWND hwnd) {
  RECT rect{};
  if (FAILED(::DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &rect, sizeof(rect)))) {
    ::GetWindowRect(hwnd, &rect);
  }
  return rect;
}

std::string AppName(HWND hwnd) {
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  const HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    return "";
  }
  wchar_t path[MAX_PATH] = {};
  DWORD size = MAX_PATH;
  std::string name;
  if (::QueryFullProcessImageNameW(process, 0, path, &size)) {
    name = WideToUtf8(std::filesystem::path(path).stem().wstring());
  }
  ::CloseHandle(process);
  return name;
}

std::string TitleOf(HWND hwnd) {
  const int length = ::GetWindowTextLengthW(hwnd);
  if (length <= 0) {
    return "";
  }
  std::wstring title(static_cast<size_t>(length) + 1, L'\0');
  ::GetWindowTextW(hwnd, title.data(), length + 1);
  title.resize(static_cast<size_t>(length));
  return WideToUtf8(title);
}

}  // namespace

std::string WindowTitle(HWND hwnd) { return TitleOf(hwnd); }

bool IsRecordableWindow(HWND hwnd) {
  if (!::IsWindow(hwnd) || !::IsWindowVisible(hwnd) || ::IsIconic(hwnd) ||
      ::GetAncestor(hwnd, GA_ROOT) != hwnd || IsCloaked(hwnd) || IsShellWindow(hwnd)) {
    return false;
  }
  const LONG_PTR ex_style = ::GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
  if ((ex_style & WS_EX_TOOLWINDOW) != 0 && (ex_style & WS_EX_APPWINDOW) == 0) {
    return false;
  }
  const RECT bounds = VisibleBounds(hwnd);
  return bounds.right - bounds.left >= kMinimumSize &&
         bounds.bottom - bounds.top >= kMinimumSize;
}

std::vector<WindowInfo> ListCaptureWindows(DWORD exclude_process) {
  struct Context {
    DWORD exclude;
    std::vector<WindowInfo> windows;
  } context{exclude_process, {}};

  ::EnumWindows(
      [](HWND hwnd, LPARAM data) -> BOOL {
        auto* ctx = reinterpret_cast<Context*>(data);
        DWORD pid = 0;
        ::GetWindowThreadProcessId(hwnd, &pid);
        if (pid == ctx->exclude || !IsRecordableWindow(hwnd)) {
          return TRUE;
        }
        WindowInfo info;
        info.hwnd = hwnd;
        info.title = TitleOf(hwnd);
        if (info.title.empty()) {
          return TRUE;
        }
        info.app_name = AppName(hwnd);
        const RECT bounds = VisibleBounds(hwnd);
        info.width = bounds.right - bounds.left;
        info.height = bounds.bottom - bounds.top;
        ctx->windows.push_back(std::move(info));
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&context));
  return context.windows;
}

}  // namespace reclite_engine
