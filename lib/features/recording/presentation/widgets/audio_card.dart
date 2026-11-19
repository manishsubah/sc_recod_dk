import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

/// System sound / microphone toggles with live level meters.
class AudioCard extends StatelessWidget {
  const AudioCard({super.key, required this.microphoneSupported});

  /// False on systems where the engine can't capture the mic yet.
  final bool microphoneSupported;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    final cubit = context.read<AudioCubit>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: BlocBuilder<AudioCubit, AudioState>(
          builder: (context, state) => Column(
            children: [
              _AudioRow(
                icon: Icons.volume_up_outlined,
                label: 'System sound',
                value: state.systemAudio,
                onChanged: busy ? null : cubit.setSystemAudio,
                meter: _Meter(
                  active: state.systemAudio,
                  select: (levels) => levels.system,
                ),
              ),
              const Divider(),
              _AudioRow(
                icon: Icons.mic_none_outlined,
                label: 'Microphone',
                value: state.microphone,
                onChanged: busy || !microphoneSupported
                    ? null
                    : cubit.setMicrophone,
                meter: _Meter(
                  active: state.microphone,
                  select: (levels) => levels.microphone,
                ),
                hint: !microphoneSupported
                    ? const Text('Needs macOS 15 or later for now.')
                    : state.microphoneBlocked
                    ? Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Microphone access is off.'),
                          TextButton(
                            onPressed: cubit.openMicrophoneSettings,
                            child: const Text('Open System Settings'),
                          ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioRow extends StatelessWidget {
  const _AudioRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.meter,
    this.hint,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget meter;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSize.iconMd,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: AppLayout.labelColumnWidth,
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Switch(value: value, onChanged: onChanged),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: meter),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSize.iconMd + AppSpacing.sm,
                bottom: AppSpacing.xxs,
              ),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                child: hint!,
              ),
            ),
        ],
      ),
    );
  }
}

/// The only part that rebuilds on level updates.
class _Meter extends StatelessWidget {
  const _Meter({required this.active, required this.select});

  final bool active;
  final double Function(AudioLevels levels) select;

  @override
  Widget build(BuildContext context) {
    final level = context.select<AudioLevelsCubit, double>(
      (c) => active ? select(c.state) : 0,
    );
    final scheme = Theme.of(context).colorScheme;
    final color = level > 0.9
        ? AppColors.recording
        : level > 0.7
        ? AppColors.warning
        : AppColors.success;

    return SizedBox(
      width: AppSize.meterWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: LinearProgressIndicator(
          value: level,
          minHeight: AppSize.meterHeight,
          color: color,
          backgroundColor: active
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerHigh,
        ),
      ),
    );
  }
}
