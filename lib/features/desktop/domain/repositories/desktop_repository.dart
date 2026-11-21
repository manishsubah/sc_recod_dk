import 'package:reclite/features/desktop/domain/entities/tray.dart';

/// The app's window and tray / menu-bar icon. Best effort: failures are ignored.
abstract interface class DesktopRepository {
  /// Menu items chosen in the tray. For [TrayCommand.showWindow] the window is
  /// already in front.
  Stream<TrayCommand> get trayCommands;

  Future<void> setTrayStatus(TrayStatus status);

  /// Small always-on-top bar (true) or the normal window (false).
  Future<void> setMiniWindow({required bool mini});

  /// Moves the window with the mouse; call on pointer down.
  Future<void> startWindowDrag();
}
