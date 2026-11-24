import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/widgets/pane.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/presentation/bloc/shortcuts_cubit.dart';

/// `Ctrl+Alt+R` on Windows, `⌃⌥R` on macOS.
String formatKeyCombo(KeyCombo combo, {required bool mac}) {
  if (mac) {
    return [
      if (combo.control) '⌃',
      if (combo.alt) '⌥',
      if (combo.shift) '⇧',
      if (combo.meta) '⌘',
      combo.key,
    ].join();
  }
  return [
    if (combo.control) 'Ctrl',
    if (combo.alt) 'Alt',
    if (combo.shift) 'Shift',
    if (combo.meta) 'Win',
    combo.key,
  ].join('+');
}

/// The keys of a combo as separate caps: `Ctrl` `Alt` `R`, or `⌃` `⌥` `R`.
List<String> keyComboParts(KeyCombo combo, {required bool mac}) => mac
    ? [
        if (combo.control) '⌃',
        if (combo.alt) '⌥',
        if (combo.shift) '⇧',
        if (combo.meta) '⌘',
        combo.key,
      ]
    : [
        if (combo.control) 'Ctrl',
        if (combo.alt) 'Alt',
        if (combo.shift) 'Shift',
        if (combo.meta) 'Win',
        combo.key,
      ];

class ShortcutsCard extends StatelessWidget {
  const ShortcutsCard({super.key});

  static const _labels = {
    ShortcutAction.startStop: 'Start / stop recording',
    ShortcutAction.pauseResume: 'Pause / resume',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocBuilder<ShortcutsCubit, ShortcutsState>(
      builder: (context, state) => Pane(
        title: 'Keyboard shortcuts',
        children: [
          PaneRow(
            icon: Icons.keyboard_outlined,
            label: 'Use keyboard shortcuts',
            description: const Text(
              'Work even when RecLite is in the background.',
            ),
            control: Switch(
              value: state.enabled,
              onChanged: (on) =>
                  context.read<ShortcutsCubit>().setEnabled(enabled: on),
            ),
          ),
          for (final MapEntry(key: action, value: combo)
              in state.combos.entries)
            PaneRow(
              label: _labels[action]!,
              enabled: state.enabled,
              description: state.enabled && state.unavailable.contains(action)
                  ? Text(
                      'Used by another app',
                      style: TextStyle(color: t.danger),
                    )
                  : null,
              control: Semantics(
                label: formatKeyCombo(combo, mac: UiLook.current == UiLook.mac),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final key in keyComboParts(
                        combo,
                        mac: UiLook.current == UiLook.mac,
                      ))
                        _KeyCap(label: key, enabled: state.enabled),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xxs),
      constraints: const BoxConstraints(minWidth: AppSize.keyCap),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.pane,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          top: BorderSide(color: t.seamStrong),
          left: BorderSide(color: t.seamStrong),
          right: BorderSide(color: t.seamStrong),
          bottom: BorderSide(color: t.seamStrong, width: 2),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: enabled ? t.ink : t.inkFaint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
