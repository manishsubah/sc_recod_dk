import 'package:equatable/equatable.dart';

enum ShortcutAction { startStop, pauseResume }

/// A system-wide key combination, e.g. Ctrl+Alt+R.
class KeyCombo extends Equatable {
  const KeyCombo(
    this.key, {
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// Ctrl+Alt on Windows; Control+Option on macOS (Command combos clash with apps).
  static Map<ShortcutAction, KeyCombo> defaults() => const {
    ShortcutAction.startStop: KeyCombo('R', control: true, alt: true),
    ShortcutAction.pauseResume: KeyCombo('P', control: true, alt: true),
  };

  /// "A"-"Z", "0"-"9" or "F1"-"F12".
  final String key;
  final bool control;

  /// Alt on Windows, Option on macOS.
  final bool alt;
  final bool shift;

  /// Windows key on Windows, Command on macOS.
  final bool meta;

  @override
  List<Object?> get props => [key, control, alt, shift, meta];
}
