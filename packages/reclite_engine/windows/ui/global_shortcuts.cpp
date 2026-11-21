#include "global_shortcuts.h"

#include <cwctype>

namespace reclite_engine {
namespace {

constexpr wchar_t kWindowClass[] = L"RecLiteGlobalShortcuts";

// 0 when the key name is not supported.
UINT VirtualKey(const std::string& key) {
  if (key.size() == 1) {
    const char c = key[0];
    if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
      return static_cast<UINT>(c);  // Letter and digit virtual keys match ASCII.
    }
    return 0;
  }
  if (key.size() >= 2 && key.size() <= 3 && key[0] == 'F') {
    const int n = std::atoi(key.c_str() + 1);
    if (n >= 1 && n <= 12) {
      return static_cast<UINT>(VK_F1 + n - 1);
    }
  }
  return 0;
}

}  // namespace

GlobalShortcuts::GlobalShortcuts(std::function<void(int)> on_pressed)
    : on_pressed_(std::move(on_pressed)) {
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = &GlobalShortcuts::WindowProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kWindowClass;
  ::RegisterClassExW(&window_class);  // Fails harmlessly if already registered.
  window_ = ::CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, window_class.hInstance, nullptr);
  if (window_ != nullptr) {
    ::SetWindowLongPtrW(window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }
}

GlobalShortcuts::~GlobalShortcuts() {
  Clear();
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
  }
}

std::vector<int> GlobalShortcuts::Set(const std::vector<Shortcut>& shortcuts) {
  Clear();
  std::vector<int> failed;
  for (size_t i = 0; i < shortcuts.size(); ++i) {
    const Shortcut& s = shortcuts[i];
    const UINT key = VirtualKey(s.key);
    UINT modifiers = MOD_NOREPEAT;
    if (s.control) modifiers |= MOD_CONTROL;
    if (s.alt) modifiers |= MOD_ALT;
    if (s.shift) modifiers |= MOD_SHIFT;
    if (s.meta) modifiers |= MOD_WIN;
    const int id = static_cast<int>(i) + 1;  // Hotkey ids must be non-zero.
    if (window_ == nullptr || key == 0 || !::RegisterHotKey(window_, id, modifiers, key)) {
      failed.push_back(static_cast<int>(i));
      continue;
    }
    registered_ids_.push_back(id);
  }
  return failed;
}

void GlobalShortcuts::Clear() {
  for (const int id : registered_ids_) {
    ::UnregisterHotKey(window_, id);
  }
  registered_ids_.clear();
}

LRESULT CALLBACK GlobalShortcuts::WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                             LPARAM lparam) {
  if (message == WM_HOTKEY) {
    auto* self =
        reinterpret_cast<GlobalShortcuts*>(::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (self != nullptr && self->on_pressed_) {
      self->on_pressed_(static_cast<int>(wparam) - 1);
    }
    return 0;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace reclite_engine
