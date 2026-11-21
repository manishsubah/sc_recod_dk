#ifndef RECLITE_ENGINE_UI_TRAY_ICON_H_
#define RECLITE_ENGINE_UI_TRAY_ICON_H_

#include <functional>

#include "../core/win.h"
#include "../messages.g.h"

#include <shellapi.h>

namespace reclite_engine {

// Notification-area icon: the app icon when idle, a red / amber dot while
// recording / paused, and a right-click menu. Platform thread only.
class TrayIcon {
 public:
  explicit TrayIcon(std::function<void(EngineTrayCommand)> on_command);
  ~TrayIcon();

  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  void SetState(EngineTrayState state);

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  void Show();
  void ShowMenu();

  HWND window_ = nullptr;
  UINT taskbar_created_ = 0;
  std::function<void(EngineTrayCommand)> on_command_;
  EngineTrayState state_ = EngineTrayState::kIdle;
  bool shown_ = false;
  HICON app_icon_ = nullptr;
  HICON recording_icon_ = nullptr;
  HICON paused_icon_ = nullptr;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_UI_TRAY_ICON_H_
