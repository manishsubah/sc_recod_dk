import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/domain/repositories/shortcuts_repository.dart';

part 'shortcuts_state.dart';

class ShortcutsCubit extends Cubit<ShortcutsState> {
  ShortcutsCubit(this._shortcuts)
    : super(
        ShortcutsState(
          enabled: _shortcuts.enabled,
          combos: KeyCombo.defaults(),
        ),
      );

  final ShortcutsRepository _shortcuts;

  /// Presses of the registered shortcuts, for the app shell to act on.
  Stream<ShortcutAction> get pressed => _shortcuts.pressed;

  /// Registers the saved choice with the system; call once at launch.
  Future<void> start() => _apply(enabled: state.enabled);

  Future<void> setEnabled({required bool enabled}) async {
    await _shortcuts.setEnabled(enabled: enabled);
    await _apply(enabled: enabled);
  }

  Future<void> _apply({required bool enabled}) async {
    final unavailable = await _shortcuts.register(
      enabled ? state.combos : const {},
    );
    emit(state.copyWith(enabled: enabled, unavailable: unavailable));
  }
}
