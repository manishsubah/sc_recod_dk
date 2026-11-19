#include "area_windows.h"

#include <windowsx.h>

#include <algorithm>
#include <cwchar>
#include <string>

namespace reclite_engine {
namespace {

constexpr wchar_t kSelectorClass[] = L"RecLiteAreaSelector";
constexpr wchar_t kHighlightClass[] = L"RecLiteAreaHighlight";
// Pixels in this colour are fully transparent (the "hole" in the dimmed overlay).
constexpr COLORREF kTransparentKey = RGB(255, 0, 255);
constexpr BYTE kDimAlpha = 110;
constexpr int kOutline = 3;

void RegisterClassOnce(const wchar_t* name, WNDPROC proc, HCURSOR cursor) {
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = proc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.hCursor = cursor;
  window_class.lpszClassName = name;
  ::RegisterClassExW(&window_class);  // Fails harmlessly when already registered.
}

RECT MonitorBounds(HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  ::GetMonitorInfoW(monitor, &info);
  return info.rcMonitor;
}

void DrawLabel(HDC dc, const std::wstring& text, int center_x, int center_y) {
  ::SetBkMode(dc, TRANSPARENT);
  ::SetTextColor(dc, RGB(255, 255, 255));
  RECT box{center_x - 300, center_y - 14, center_x + 300, center_y + 14};
  ::DrawTextW(dc, text.c_str(), -1, &box, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
}

}  // namespace

AreaSelector::~AreaSelector() { Finish(std::nullopt); }

void AreaSelector::Select(HMONITOR monitor, Done done) {
  Finish(std::nullopt);
  done_ = std::move(done);
  dragging_ = false;
  has_selection_ = false;

  RegisterClassOnce(kSelectorClass, &AreaSelector::WindowProc,
                    ::LoadCursorW(nullptr, IDC_CROSS));
  const RECT bounds = MonitorBounds(monitor);
  window_ = ::CreateWindowExW(WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW, kSelectorClass,
                              L"", WS_POPUP, bounds.left, bounds.top,
                              bounds.right - bounds.left, bounds.bottom - bounds.top, nullptr,
                              nullptr, ::GetModuleHandleW(nullptr), this);
  if (window_ == nullptr) {
    Finish(std::nullopt);
    return;
  }
  ::SetLayeredWindowAttributes(window_, kTransparentKey, kDimAlpha, LWA_COLORKEY | LWA_ALPHA);
  ::SetWindowDisplayAffinity(window_, WDA_EXCLUDEFROMCAPTURE);
  ::ShowWindow(window_, SW_SHOW);
  ::SetForegroundWindow(window_);
  ::SetFocus(window_);
}

RECT AreaSelector::Selection() const {
  return RECT{std::min(start_.x, current_.x), std::min(start_.y, current_.y),
              std::max(start_.x, current_.x), std::max(start_.y, current_.y)};
}

void AreaSelector::Finish(std::optional<RECT> result) {
  if (window_ != nullptr) {
    const HWND window = window_;
    window_ = nullptr;
    ::SetWindowLongPtrW(window, GWLP_USERDATA, 0);
    ::DestroyWindow(window);
  }
  if (done_) {
    auto done = std::move(done_);
    done_ = nullptr;
    done(result);
  }
}

void AreaSelector::Paint(HWND hwnd) {
  PAINTSTRUCT paint;
  const HDC screen_dc = ::BeginPaint(hwnd, &paint);
  RECT client;
  ::GetClientRect(hwnd, &client);

  // Draw off-screen first so dragging doesn't flicker.
  const HDC dc = ::CreateCompatibleDC(screen_dc);
  const HBITMAP bitmap = ::CreateCompatibleBitmap(screen_dc, client.right, client.bottom);
  const HGDIOBJ old_bitmap = ::SelectObject(dc, bitmap);

  const HBRUSH dim = ::CreateSolidBrush(RGB(0, 0, 0));
  ::FillRect(dc, &client, dim);
  ::DeleteObject(dim);

  if (has_selection_ || dragging_) {
    const RECT selection = Selection();
    const HBRUSH hole = ::CreateSolidBrush(kTransparentKey);
    ::FillRect(dc, &selection, hole);
    ::DeleteObject(hole);
    const HBRUSH border = ::CreateSolidBrush(RGB(255, 255, 255));
    RECT frame = selection;
    ::InflateRect(&frame, 2, 2);
    ::FrameRect(dc, &frame, border);
    ::InflateRect(&frame, -1, -1);
    ::FrameRect(dc, &frame, border);
    ::DeleteObject(border);

    wchar_t size[48];
    std::swprintf(size, 48, L"%ld × %ld", selection.right - selection.left,
                  selection.bottom - selection.top);
    DrawLabel(dc, size, (selection.left + selection.right) / 2,
              std::min<int>(selection.bottom + 22, client.bottom - 20));
  } else {
    DrawLabel(dc, L"Drag to select the area to record  ·  Esc to cancel",
              client.right / 2, 80);
  }

  ::BitBlt(screen_dc, 0, 0, client.right, client.bottom, dc, 0, 0, SRCCOPY);
  ::SelectObject(dc, old_bitmap);
  ::DeleteObject(bitmap);
  ::DeleteDC(dc);
  ::EndPaint(hwnd, &paint);
}

LRESULT AreaSelector::Handle(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_LBUTTONDOWN:
      ::SetCapture(hwnd);
      dragging_ = true;
      start_ = current_ = POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ::InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_MOUSEMOVE:
      if (dragging_) {
        current_ = POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        ::InvalidateRect(hwnd, nullptr, FALSE);
      }
      return 0;
    case WM_LBUTTONUP: {
      if (!dragging_) {
        return 0;
      }
      ::ReleaseCapture();
      dragging_ = false;
      current_ = POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      const RECT selection = Selection();
      if (selection.right - selection.left >= kMinimumSize &&
          selection.bottom - selection.top >= kMinimumSize) {
        Finish(selection);
      } else {
        has_selection_ = false;
        ::InvalidateRect(hwnd, nullptr, FALSE);
      }
      return 0;
    }
    case WM_RBUTTONDOWN:
      Finish(std::nullopt);
      return 0;
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE) {
        Finish(std::nullopt);
      }
      return 0;
    default:
      return ::DefWindowProcW(hwnd, message, wparam, lparam);
  }
}

LRESULT CALLBACK AreaSelector::WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                          LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(hwnd, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* self = reinterpret_cast<AreaSelector*>(::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  return self != nullptr ? self->Handle(hwnd, message, wparam, lparam)
                         : ::DefWindowProcW(hwnd, message, wparam, lparam);
}

AreaHighlight::~AreaHighlight() { Hide(); }

void AreaHighlight::Show(HMONITOR monitor, RECT area) {
  Hide();
  RegisterClassOnce(kHighlightClass, &AreaHighlight::WindowProc, nullptr);
  const RECT bounds = MonitorBounds(monitor);
  const int left = bounds.left + area.left - kOutline;
  const int top = bounds.top + area.top - kOutline;
  const int width = (area.right - area.left) + 2 * kOutline;
  const int height = (area.bottom - area.top) + 2 * kOutline;
  window_ = ::CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kHighlightClass, L"", WS_POPUP, left, top, width, height, nullptr, nullptr,
      ::GetModuleHandleW(nullptr), nullptr);
  if (window_ == nullptr) {
    return;
  }
  ::SetLayeredWindowAttributes(window_, kTransparentKey, 255, LWA_COLORKEY);
  ::SetWindowDisplayAffinity(window_, WDA_EXCLUDEFROMCAPTURE);
  ::ShowWindow(window_, SW_SHOWNOACTIVATE);
}

void AreaHighlight::Hide() {
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

LRESULT CALLBACK AreaHighlight::WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                           LPARAM lparam) {
  if (message == WM_PAINT) {
    PAINTSTRUCT paint;
    const HDC dc = ::BeginPaint(hwnd, &paint);
    RECT client;
    ::GetClientRect(hwnd, &client);
    const HBRUSH hole = ::CreateSolidBrush(kTransparentKey);
    ::FillRect(dc, &client, hole);
    ::DeleteObject(hole);
    const HBRUSH red = ::CreateSolidBrush(RGB(229, 56, 59));
    for (int i = 0; i < kOutline; ++i) {
      ::FrameRect(dc, &client, red);
      ::InflateRect(&client, -1, -1);
    }
    ::DeleteObject(red);
    ::EndPaint(hwnd, &paint);
    return 0;
  }
  if (message == WM_ERASEBKGND) {
    return 1;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace reclite_engine
