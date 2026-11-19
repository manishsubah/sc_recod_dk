import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

/// Start button, live recording indicator, or the "saved" summary.
class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.canRecord,
    required this.outputFolder,
  });

  final bool canRecord;
  final String outputFolder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      // Status ticks are handled by _RecordingIndicator's own selector.
      buildWhen: (a, b) =>
          a.runtimeType != b.runtimeType ||
          b is RecordingFailed ||
          b is RecordingFinished,
      builder: (context, state) => switch (state) {
        RecordingIdle() => _StartButton(
          canRecord: canRecord,
          outputFolder: outputFolder,
        ),
        RecordingFailed(:final message) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ErrorBanner(message: message),
            const SizedBox(height: AppSpacing.md),
            _StartButton(canRecord: canRecord, outputFolder: outputFolder),
          ],
        ),
        RecordingStarting() => const _BusyButton(label: 'Starting…'),
        RecordingActive() || RecordingStopping() => const _RecordingIndicator(),
        RecordingFinished(:final result) => _SavedCard(result: result),
      },
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.canRecord, required this.outputFolder});

  final bool canRecord;
  final String outputFolder;

  @override
  Widget build(BuildContext context) {
    final source = context.select<SourcesCubit, SourcesLoaded?>(
      (c) => switch (c.state) {
        final SourcesLoaded loaded => loaded,
        _ => null,
      },
    );
    final audio = context.watch<AudioCubit>().state;
    final enabled = canRecord && source != null;

    return Center(
      child: FilledButton.icon(
        onPressed: enabled
            ? () => context.read<RecordingBloc>().add(
                RecordingStartRequested(
                  RecordingConfig(
                    displayId: source.selectedId,
                    area: source.area,
                    captureSystemAudio: audio.systemAudio,
                    captureMicrophone: audio.microphone,
                    outputFolder: outputFolder,
                    framesPerSecond: RecordingDefaults.framesPerSecond,
                    maxHeight: RecordingDefaults.maxOutputHeight,
                  ),
                ),
              )
            : null,
        icon: const Icon(Icons.fiber_manual_record, color: AppColors.recording),
        label: const Text('Start Recording'),
      ),
    );
  }
}

class _BusyButton extends StatelessWidget {
  const _BusyButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: null,
        icon: const SizedBox.square(
          dimension: AppSize.inlineProgress,
          child: CircularProgressIndicator(strokeWidth: AppSize.progressStroke),
        ),
        label: Text(label),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stopping = context.select<RecordingBloc, bool>(
      (b) => b.state is RecordingStopping,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: AppSize.recordDot,
              height: AppSize.recordDot,
              decoration: const BoxDecoration(
                color: AppColors.recording,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'REC',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.recording,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(child: _LiveStatus()),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.recording,
                foregroundColor: Colors.white,
              ),
              onPressed: stopping
                  ? null
                  : () => context.read<RecordingBloc>().add(
                      const RecordingStopRequested(),
                    ),
              icon: stopping
                  ? const SizedBox.square(
                      dimension: AppSize.inlineProgress,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSize.progressStroke,
                      ),
                    )
                  : const Icon(Icons.stop_rounded),
              label: Text(stopping ? 'Saving…' : 'Stop'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The only widget that rebuilds on every status tick.
class _LiveStatus extends StatelessWidget {
  const _LiveStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.select<RecordingBloc, RecordingStatus>(
      (b) => switch (b.state) {
        RecordingActive(:final status) => status,
        RecordingStopping(:final lastStatus) => lastStatus,
        _ => RecordingStatus.initial,
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatElapsed(status.elapsed),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'Part ${status.segmentIndex} · ${formatBytes(status.bytesWritten)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.result});

  final RecordingResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<RecordingBloc>();
    final file = result.files.isEmpty ? null : result.files.first;
    final revealLabel = Platform.isMacOS
        ? 'Show in Finder'
        : 'Show in Explorer';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text('Recording saved', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (file != null)
              SelectableText(
                file.split(Platform.pathSeparator).last,
                style: theme.textTheme.bodyMedium,
              ),
            Text(
              '${formatElapsed(result.duration)} · '
              '${formatBytes(result.bytesWritten)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (file != null)
                  OutlinedButton.icon(
                    onPressed: () => bloc.add(RecordingRevealRequested(file)),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(revealLabel),
                  ),
                FilledButton.tonal(
                  onPressed: () => bloc.add(const RecordingDismissed()),
                  child: const Text('New recording'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              color: scheme.onErrorContainer,
              onPressed: () =>
                  context.read<RecordingBloc>().add(const RecordingDismissed()),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
