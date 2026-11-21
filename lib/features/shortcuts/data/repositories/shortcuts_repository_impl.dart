import 'package:flutter/services.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/domain/repositories/shortcuts_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShortcutsRepositoryImpl implements ShortcutsRepository {
  ShortcutsRepositoryImpl(this._engine, this._prefs);

  static const _enabledKey = 'shortcuts_enabled';

  final RecliteEngine _engine;
  final SharedPreferences _prefs;

  /// The engine reports presses by index into the last registered list.
  List<ShortcutAction> _registered = const [];

  @override
  Stream<ShortcutAction> get pressed => _engine.shortcutPresses
      .where((i) => i >= 0 && i < _registered.length)
      .map((i) => _registered[i]);

  @override
  bool get enabled => _prefs.getBool(_enabledKey) ?? true;

  @override
  Future<void> setEnabled({required bool enabled}) =>
      _prefs.setBool(_enabledKey, enabled);

  @override
  Future<Set<ShortcutAction>> register(
    Map<ShortcutAction, KeyCombo> shortcuts,
  ) async {
    final actions = shortcuts.keys.toList();
    try {
      final failed = await _engine.setGlobalShortcuts([
        for (final action in actions)
          EngineShortcut(
            key: shortcuts[action]!.key,
            control: shortcuts[action]!.control,
            alt: shortcuts[action]!.alt,
            shift: shortcuts[action]!.shift,
            meta: shortcuts[action]!.meta,
          ),
      ]);
      _registered = actions;
      return {for (final i in failed) actions[i]};
    } on PlatformException {
      _registered = const [];
      return actions.toSet();
    }
  }
}
