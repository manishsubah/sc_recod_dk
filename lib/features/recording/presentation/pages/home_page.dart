import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/recording_defaults.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/page_scaffold.dart';
import '../bloc/readiness_cubit.dart';
import '../widgets/info_row.dart';
import '../widgets/readiness_header.dart';

/// Home / recording dashboard (docs/PLAN.md §21.1).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Record',
      child: BlocBuilder<ReadinessCubit, ReadinessState>(
        builder: (context, state) => switch (state) {
          ReadinessLoading() => const Padding(
            padding: EdgeInsets.all(48),
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
        ReadinessHeader(canRecord: state.canRecord, issues: state.issues),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  value:
                      '${RecordingDefaults.segmentDuration.inMinutes} minutes',
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            // Enabled in Phase 1, when the recording pipeline lands.
            onPressed: null,
            icon: const Icon(
              Icons.fiber_manual_record,
              color: AppTheme.recording,
            ),
            label: const Text('Start Recording'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Recording engine arrives in the next build. '
          'Engine ${engine.engineVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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
