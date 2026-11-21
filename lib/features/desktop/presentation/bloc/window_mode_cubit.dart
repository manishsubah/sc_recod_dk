import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';

enum WindowMode { full, mini }

/// Normal window or mini recording bar, plus the tray icon's look.
class WindowModeCubit extends Cubit<WindowMode> {
  WindowModeCubit(this._desktop) : super(WindowMode.full);

  final DesktopRepository _desktop;
  TrayStatus? _tray;

  Stream<TrayCommand> get trayCommands => _desktop.trayCommands;

  Future<void> showMini() async {
    if (state == WindowMode.mini) return;
    emit(WindowMode.mini);
    await _desktop.setMiniWindow(mini: true);
  }

  /// The window grows first, so the full page is never laid out at bar size.
  Future<void> showFull() async {
    if (state == WindowMode.full) return;
    await _desktop.setMiniWindow(mini: false);
    emit(WindowMode.full);
  }

  Future<void> startDrag() => _desktop.startWindowDrag();

  Future<void> showTrayStatus(TrayStatus status) async {
    if (status == _tray) return;
    _tray = status;
    await _desktop.setTrayStatus(status);
  }
}
