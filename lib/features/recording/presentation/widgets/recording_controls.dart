import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

/// Live recording indicator, the "saved" summary or a failure message. Nothing
/// while idle: recording starts from the page's top-right button.
class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      // Status ticks are handled by _RecordingIndicator's own selector.
      buildWhen: (a, b) =>
          a.runtimeType != b.runtimeType ||
          b is RecordingFailed ||
          b is RecordingFinished,
      builder: (context, state) => switch (state) {
        RecordingIdle() || RecordingStarting() => const SizedBox.shrink(),
        RecordingFailed(:final message) => _ErrorBanner(message: message),
        RecordingActive() || RecordingStopping() => const _RecordingIndicator(),
        RecordingFinished(:final result) => _SavedCard(result: result),
      },
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  static const _compact = Size(
    AppSize.compactButtonWidth,
    AppSize.buttonHeight,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<RecordingBloc>();
    final (stopping, paused, warning) = context
        .select<RecordingBloc, (bool, bool, String?)>(
          (b) => switch (b.state) {
            RecordingStopping() => (true, false, null),
            final RecordingActive a => (false, a.isPaused, a.warning),
            _ => (false, false, null),
          },
        );
    final accent = paused ? theme.colorScheme.outline : AppColors.recording;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: AppSize.recordDot,
                  height: AppSize.recordDot,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  paused ? 'PAUSED' : 'REC',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(child: _LiveStatus()),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: _compact),
                  onPressed: stopping
                      ? null
                      : () => bloc.add(
                          paused
                              ? const RecordingResumeRequested()
                              : const RecordingPauseRequested(),
                        ),
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(paused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: _compact,
                    backgroundColor: AppColors.recording,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: stopping
                      ? null
                      : () => bloc.add(const RecordingStopRequested()),
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
            if (warning != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: AppSize.iconMd,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(warning, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
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
    final parts = result.files.length;
    final file = result.files.isEmpty ? null : result.files.first;
    final revealTarget = parts > 1 ? result.sessionDirectory : file;
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
            if (parts > 1)
              SelectableText(
                fileNameOf(result.sessionDirectory),
                style: theme.textTheme.bodyMedium,
              )
            else if (file != null)
              SelectableText(
                fileNameOf(file),
                style: theme.textTheme.bodyMedium,
              ),
            Text(
              '${formatElapsed(result.duration)} · '
              '${formatBytes(result.bytesWritten)}'
              '${parts > 1 ? ' · $parts parts' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (revealTarget != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        bloc.add(RecordingRevealRequested(revealTarget)),
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
