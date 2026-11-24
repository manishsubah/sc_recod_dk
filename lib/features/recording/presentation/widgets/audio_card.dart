import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/widgets/level_meter.dart';
import 'package:reclite/core/widgets/pane.dart';
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

    return BlocBuilder<AudioCubit, AudioState>(
      builder: (context, state) => Pane(
        title: 'Audio',
        children: [
          PaneRow(
            icon: Icons.volume_up_outlined,
            label: 'System sound',
            enabled: !busy,
            control: _Control(
              value: state.systemAudio,
              onChanged: busy ? null : cubit.setSystemAudio,
              meter: _Meter(
                active: state.systemAudio,
                select: (levels) => levels.system,
              ),
            ),
          ),
          PaneRow(
            icon: Icons.mic_none_outlined,
            label: 'Microphone',
            enabled: !busy && microphoneSupported,
            description: !microphoneSupported
                ? const Text('Needs macOS 15 or later for now.')
                : null,
            control: _Control(
              value: state.microphone,
              onChanged: busy || !microphoneSupported
                  ? null
                  : cubit.setMicrophone,
              meter: _Meter(
                active: state.microphone,
                select: (levels) => levels.microphone,
              ),
            ),
            below: microphoneSupported && state.microphoneBlocked
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: AppSize.iconLg + AppSpacing.sm,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          'Microphone access is off.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: cubit.openMicrophoneSettings,
                          child: const Text('Open System Settings'),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.value,
    required this.onChanged,
    required this.meter,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget meter;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        meter,
        const SizedBox(width: AppSpacing.md),
        Switch(value: value, onChanged: onChanged),
      ],
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
    return LevelMeter(level: level, active: active);
  }
}
