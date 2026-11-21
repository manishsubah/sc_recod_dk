import 'package:flutter/services.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

class DesktopRepositoryImpl implements DesktopRepository {
  DesktopRepositoryImpl(this._engine);

  final RecliteEngine _engine;

  @override
  Stream<TrayCommand> get trayCommands => _engine.trayCommands.map(
    (c) => switch (c) {
      EngineTrayCommand.startStop => TrayCommand.startStop,
      EngineTrayCommand.pauseResume => TrayCommand.pauseResume,
      EngineTrayCommand.showWindow => TrayCommand.showWindow,
    },
  );

  @override
  Future<void> setTrayStatus(TrayStatus status) => _quietly(
    () => _engine.setTrayState(switch (status) {
      TrayStatus.idle => EngineTrayState.idle,
      TrayStatus.recording => EngineTrayState.recording,
      TrayStatus.paused => EngineTrayState.paused,
    }),
  );

  @override
  Future<void> setMiniWindow({required bool mini}) =>
      _quietly(() => _engine.setMiniWindow(mini));

  @override
  Future<void> startWindowDrag() => _quietly(_engine.startWindowDrag);

  /// Window and tray changes are cosmetic; recording must never fail because of them.
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException {
      // Ignored on purpose (see above).
    } on MissingPluginException {
      // Ignored on purpose (see above).
    }
  }
}
