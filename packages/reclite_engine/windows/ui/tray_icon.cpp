#include "tray_icon.h"

#include <cmath>
#include <cwchar>
#include <vector>

namespace reclite_engine {
namespace {

constexpr wchar_t kWindowClass[] = L"RecLiteTrayIcon";
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kIconId = 1;
// Icons built into the runner (windows/runner/resource.h, Runner.rc), drawn by
// tool/icon/make_icon.py.
constexpr int kRunnerAppIcon = 101;        // IDI_APP_ICON
constexpr int kRunnerTrayIdle = 102;       // IDI_TRAY_IDLE
constexpr int kRunnerTrayRecording = 103;  // IDI_TRAY_RECORDING
constexpr int kRunnerTrayPaused = 104;     // IDI_TRAY_PAUSED

enum MenuItem : UINT { kStartStop = 1, kPauseResume, kShowWindow };

// A filled, anti-aliased circle in [color] on a transparent background.
HICON DotIcon(COLORREF color) {
  const int size = ::GetSystemMetrics(SM_CXSMICON);
  BITMAPV5HEADER header{};
  header.bV5Size = sizeof(header);
  header.bV5Width = size;
  header.bV5Height = -size;  // Top-down rows.
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;

  void* bits = nullptr;
  const HDC screen = ::GetDC(nullptr);
  const HBITMAP color_bitmap =
      ::CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS,
                         &bits, nullptr, 0);
  ::ReleaseDC(nullptr, screen);
  if (color_bitmap == nullptr) {
    return nullptr;
  }

  const double center = (size - 1) / 2.0;
  const double radius = size * 0.38;
  auto* pixels = static_cast<uint32_t*>(bits);
  for (int y = 0; y < size; ++y) {
    for (int x = 0; x < size; ++x) {
      const double distance = std::hypot(x - center, y - center);
      const double coverage = std::fmin(1.0, std::fmax(0.0, radius + 0.5 - distance));
      const auto alpha = static_cast<uint32_t>(coverage * 255);
      // Premultiplied BGRA.
      const uint32_t r = GetRValue(color) * alpha / 255;
      const uint32_t g = GetGValue(color) * alpha / 255;
      const uint32_t b = GetBValue(color) * alpha / 255;
      pixels[y * size + x] = (alpha << 24) | (r << 16) | (g << 8) | b;
    }
  }

  const HBITMAP mask = ::CreateBitmap(size, size, 1, 1, nullptr);
  ICONINFO info{};
  info.fIcon = TRUE;
  info.hbmColor = color_bitmap;
  info.hbmMask = mask;
  const HICON icon = ::CreateIconIndirect(&info);
  ::DeleteObject(color_bitmap);
  ::DeleteObject(mask);
  return icon;
}

}  // namespace

TrayIcon::TrayIcon(std::function<void(EngineTrayCommand)> on_command)
    : on_command_(std::move(on_command)) {
  const HINSTANCE instance = ::GetModuleHandleW(nullptr);
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = &TrayIcon::WindowProc;
  window_class.hInstance = instance;
  window_class.lpszClassName = kWindowClass;
  ::RegisterClassExW(&window_class);
  // A hidden top-level window (not message-only) so it hears "TaskbarCreated"
  // and can put the icon back after Explorer restarts.
  window_ = ::CreateWindowExW(0, kWindowClass, L"RecLite tray", WS_POPUP, 0, 0, 0, 0,
                              nullptr, nullptr, instance, nullptr);
  if (window_ != nullptr) {
    ::SetWindowLongPtrW(window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }
  taskbar_created_ = ::RegisterWindowMessageW(L"TaskbarCreated");

  const int size = ::GetSystemMetrics(SM_CXSMICON);
  const auto load = [instance, size](int id) {
    return static_cast<HICON>(
        ::LoadImageW(instance, MAKEINTRESOURCEW(id), IMAGE_ICON, size, size, 0));
  };
  app_icon_ = load(kRunnerTrayIdle);
  if (app_icon_ == nullptr) {
    app_icon_ = load(kRunnerAppIcon);
  }
  // A plain dot if the runner was built without the tray icons.
  recording_icon_ = load(kRunnerTrayRecording);
  if (recording_icon_ == nullptr) {
    recording_icon_ = DotIcon(RGB(0xE2, 0x2E, 0x3E));  // tally red
  }
  paused_icon_ = load(kRunnerTrayPaused);
  if (paused_icon_ == nullptr) {
    paused_icon_ = DotIcon(RGB(0xDE, 0x88, 0x20));  // amber
  }
}

TrayIcon::~TrayIcon() {
  if (shown_) {
    NOTIFYICONDATAW data{};
    data.cbSize = sizeof(data);
    data.hWnd = window_;
    data.uID = kIconId;
    ::Shell_NotifyIconW(NIM_DELETE, &data);
  }
  for (HICON icon : {app_icon_, recording_icon_, paused_icon_}) {
    if (icon != nullptr) {
      ::DestroyIcon(icon);
    }
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
  }
}

void TrayIcon::SetState(EngineTrayState state) {
  state_ = state;
  Show();
}

void TrayIcon::Show() {
  if (window_ == nullptr) {
    return;
  }
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kTrayMessage;
  switch (state_) {
    case EngineTrayState::kRecording:
      data.hIcon = recording_icon_;
      wcscpy_s(data.szTip, L"RecLite - recording");
      break;
    case EngineTrayState::kPaused:
      data.hIcon = paused_icon_;
      wcscpy_s(data.szTip, L"RecLite - paused");
      break;
    default:
      data.hIcon = app_icon_;
      wcscpy_s(data.szTip, L"RecLite");
      break;
  }
  if (data.hIcon == nullptr) {
    data.hIcon = app_icon_;
  }
  if (!shown_ || !::Shell_NotifyIconW(NIM_MODIFY, &data)) {
    shown_ = ::Shell_NotifyIconW(NIM_ADD, &data) != FALSE;
  }
}

void TrayIcon::ShowMenu() {
  const HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  const bool busy = state_ != EngineTrayState::kIdle;
  ::AppendMenuW(menu, MF_STRING, kStartStop, busy ? L"Stop recording" : L"Start recording");
  if (busy) {
    ::AppendMenuW(menu, MF_STRING, kPauseResume,
                  state_ == EngineTrayState::kPaused ? L"Resume" : L"Pause");
  }
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kShowWindow, L"Show RecLite");
  ::SetMenuDefaultItem(menu, kShowWindow, FALSE);

  POINT cursor{};
  ::GetCursorPos(&cursor);
  // Without this the menu does not close when the user clicks elsewhere.
  ::SetForegroundWindow(window_);
  const UINT chosen = ::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                                       cursor.x, cursor.y, 0, window_, nullptr);
  ::PostMessageW(window_, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  switch (chosen) {
    case kStartStop:
      on_command_(EngineTrayCommand::kStartStop);
      break;
    case kPauseResume:
      on_command_(EngineTrayCommand::kPauseResume);
      break;
    case kShowWindow:
      on_command_(EngineTrayCommand::kShowWindow);
      break;
    default:
      break;
  }
}

LRESULT CALLBACK TrayIcon::WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                      LPARAM lparam) {
  auto* self = reinterpret_cast<TrayIcon*>(::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (self != nullptr) {
    if (message == kTrayMessage) {
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
          self->on_command_(EngineTrayCommand::kShowWindow);
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          self->ShowMenu();
          return 0;
        default:
          return 0;
      }
    }
    if (message == self->taskbar_created_ && self->taskbar_created_ != 0) {
      self->shown_ = false;
      self->Show();
      return 0;
    }
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace reclite_engine
