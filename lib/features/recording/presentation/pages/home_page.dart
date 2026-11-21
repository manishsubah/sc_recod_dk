import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/widgets/audio_card.dart';
import 'package:reclite/features/recording/presentation/widgets/info_row.dart';
import 'package:reclite/features/recording/presentation/widgets/readiness_header.dart';
import 'package:reclite/features/recording/presentation/widgets/recording_controls.dart';
import 'package:reclite/features/recording/presentation/widgets/recovery_banner.dart';
import 'package:reclite/features/recording/presentation/widgets/source_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Record',
      child: BlocBuilder<ReadinessCubit, ReadinessState>(
        builder: (context, state) => switch (state) {
          ReadinessLoading() => const Padding(
            padding: EdgeInsets.all(AppSpacing.huge),
            child: Center(child: CircularProgressIndicator()),
          ),
          ReadinessFailed(:final message) => _FailedView(message: message),
          final ReadinessLoaded loaded => _LoadedView(state: loaded),
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final ReadinessLoaded state;

  @override
  Widget build(BuildContext context) {
    final engine = state.engine;
    final storage = state.storage;
    final encoders = [
      if (engine.hasHardwareH264Encoder) 'H.264',
      if (engine.hasHardwareHevcEncoder) 'HEVC',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RecoveryBanner(),
        ReadinessHeader(canRecord: state.canRecord, issues: state.issues),
        const SizedBox(height: AppSpacing.md),
        if (engine.supportsRecording) ...[
          const SourceCard(),
          const SizedBox(height: AppSpacing.md),
          AudioCard(
            microphoneSupported: engine.supportsMicrophoneViaScreenCapture,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (_, s) => s is RecordingFinished || s is RecordingFailed,
          listener: (context, _) => context.read<ReadinessCubit>().refresh(),
          child: RecordingControls(canRecord: state.canRecord),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.computer_outlined,
                  label: 'System',
                  value: '${engine.platformName} ${engine.osVersion}',
                ),
                InfoRow(
                  icon: Icons.memory_outlined,
                  label: 'Hardware encoding',
                  value: encoders.isEmpty
                      ? 'Not available (software fallback)'
                      : encoders.join(' · '),
                ),
                InfoRow(
                  icon: Icons.volume_up_outlined,
                  label: 'System audio',
                  value: engine.supportsSystemAudio
                      ? 'Supported'
                      : 'Not supported',
                ),
                InfoRow(
                  icon: Icons.folder_outlined,
                  label: 'Save to',
                  value: storage.path,
                ),
                InfoRow(
                  icon: Icons.storage_outlined,
                  label: 'Free space',
                  value:
                      '${formatBytes(storage.freeBytes)} · '
                      '${formatRecordingTimeLeft(storage.freeBytes, estimatedBytesPerHour: RecordingDefaults.estimatedBytesPerHour)}',
                ),
                InfoRow(
                  icon: Icons.content_cut_outlined,
                  label: 'Split every',
                  value: formatSegmentLength(state.options.segmentDuration),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: AppSize.iconXxl,
              color: scheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.read<ReadinessCubit>().load(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
