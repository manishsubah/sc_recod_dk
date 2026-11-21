#include "window_controller.h"

#include <dwmapi.h>

namespace reclite_engine {
namespace {

// Mini bar size and gap from the top of the screen, in logical pixels.
constexpr int kMiniWidth = 380;
constexpr int kMiniHeight = 56;
constexpr int kMiniTopGap = 12;

// Windows 11 rounded corners for a window without a frame (ignored on Windows 10).
void SetRoundCorners(HWND hwnd, bool round) {
  constexpr DWORD kCornerPreference = 33;  // DWMWA_WINDOW_CORNER_PREFERENCE
  const int preference = round ? 2 : 0;    // DWMWCP_ROUND : DWMWCP_DEFAULT
  ::DwmSetWindowAttribute(hwnd, kCornerPreference, &preference, sizeof(preference));
}

}  // namespace

WindowController::WindowController(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  delegate_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleMessage(hwnd, message, wparam, lparam);
      });
}

WindowController::~WindowController() {
  registrar_->UnregisterTopLevelWindowProcDelegate(delegate_id_);
}

HWND WindowController::Root() const {
  flutter::FlutterView* view = registrar_->GetView();
  return view != nullptr ? ::GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
}

void WindowController::SetMini(bool mini) {
  const HWND hwnd = Root();
  if (hwnd == nullptr || mini == mini_) {
    return;
  }
  if (mini) {
    saved_placement_.length = sizeof(saved_placement_);
    ::GetWindowPlacement(hwnd, &saved_placement_);
    saved_style_ = ::GetWindowLongPtrW(hwnd, GWL_STYLE);
    saved_ex_style_ = ::GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    mini_ = true;  // Before resizing, so the minimum size is already lifted.

    if (::IsZoomed(hwnd) || ::IsIconic(hwnd)) {
      ::ShowWindow(hwnd, SW_RESTORE);
    }
    ::SetWindowLongPtrW(hwnd, GWL_STYLE,
                        saved_style_ & ~static_cast<LONG_PTR>(WS_CAPTION | WS_THICKFRAME));
    SetRoundCorners(hwnd, true);

    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    ::GetMonitorInfoW(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor);
    const double scale = ::GetDpiForWindow(hwnd) / 96.0;
    const int width = static_cast<int>(kMiniWidth * scale);
    const int height = static_cast<int>(kMiniHeight * scale);
    const RECT& work = monitor.rcWork;
    const int x = work.left + (work.right - work.left - width) / 2;
    const int y = work.top + static_cast<int>(kMiniTopGap * scale);
    ::SetWindowPos(hwnd, HWND_TOPMOST, x, y, width, height,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    return;
  }

  ::SetWindowLongPtrW(hwnd, GWL_STYLE, saved_style_);
  ::SetWindowLongPtrW(hwnd, GWL_EXSTYLE, saved_ex_style_);
  SetRoundCorners(hwnd, false);
  ::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
  mini_ = false;
  saved_placement_.showCmd = SW_SHOWNORMAL;
  ::SetWindowPlacement(hwnd, &saved_placement_);
  BringToFront();
}

void WindowController::StartDrag() {
  const HWND hwnd = Root();
  if (hwnd == nullptr) {
    return;
  }
  // Hands the press to Windows as a title-bar drag.
  ::ReleaseCapture();
  ::SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void WindowController::BringToFront() {
  const HWND hwnd = Root();
  if (hwnd == nullptr) {
    return;
  }
  if (::IsIconic(hwnd) || !::IsWindowVisible(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }
  ::SetForegroundWindow(hwnd);
}

std::optional<LRESULT> WindowController::HandleMessage(HWND, UINT message, WPARAM,
                                                       LPARAM lparam) {
  if (mini_ && message == WM_GETMINMAXINFO) {
    auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
    info->ptMinTrackSize = {1, 1};
    return 0;
  }
  return std::nullopt;
}

}  // namespace reclite_engine
