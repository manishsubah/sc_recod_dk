import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
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

class ShortcutsCard extends StatelessWidget {
  const ShortcutsCard({super.key});

  static const _labels = {
    ShortcutAction.startStop: 'Start / stop recording',
    ShortcutAction.pauseResume: 'Pause / resume',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: BlocBuilder<ShortcutsCubit, ShortcutsState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.keyboard_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Keyboard shortcuts',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Switch(
                    value: state.enabled,
                    onChanged: (on) =>
                        context.read<ShortcutsCubit>().setEnabled(enabled: on),
                  ),
                ],
              ),
              Text(
                'Work even when RecLite is in the background.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final MapEntry(key: action, value: combo)
                  in state.combos.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labels[action]!,
                          style: state.enabled ? null : muted,
                        ),
                      ),
                      if (state.enabled && state.unavailable.contains(action))
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Text(
                            'Used by another app',
                            style: muted?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      Text(
                        formatKeyCombo(combo, mac: Platform.isMacOS),
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
