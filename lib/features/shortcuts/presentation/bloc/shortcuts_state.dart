part of 'shortcuts_cubit.dart';

class ShortcutsState extends Equatable {
  const ShortcutsState({
    required this.enabled,
    required this.combos,
    this.unavailable = const {},
  });

  final bool enabled;
  final Map<ShortcutAction, KeyCombo> combos;

  /// Shortcuts another app already uses; they do nothing in RecLite.
  final Set<ShortcutAction> unavailable;

  ShortcutsState copyWith({bool? enabled, Set<ShortcutAction>? unavailable}) =>
      ShortcutsState(
        enabled: enabled ?? this.enabled,
        combos: combos,
        unavailable: unavailable ?? this.unavailable,
      );

  @override
  List<Object?> get props => [enabled, combos, unavailable];
}
