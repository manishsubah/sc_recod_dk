import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';

abstract interface class ShortcutsRepository {
  /// Fires while RecLite runs, even when another app has focus.
  Stream<ShortcutAction> get pressed;

  bool get enabled;

  Future<void> setEnabled({required bool enabled});

  /// Replaces all system-wide shortcuts; an empty map turns them off.
  /// Returns the actions whose keys another app already uses.
  Future<Set<ShortcutAction>> register(Map<ShortcutAction, KeyCombo> shortcuts);
}
