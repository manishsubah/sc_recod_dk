import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/info_bar.dart';
import 'package:reclite/core/widgets/part_strip.dart';
import 'package:reclite/core/widgets/tally_dot.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

/// The live transport, the "saved" summary or a failure message. Nothing while
/// idle: recording starts from the page's top-right button.
class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key, required this.partLength});

  /// Length of one MP4 part, for the live strip and "next part" countdown.
  final Duration partLength;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      // Status ticks are handled by _LiveStatus's own selector.
      buildWhen: (a, b) =>
          a.runtimeType != b.runtimeType ||
          b is RecordingFailed ||
          b is RecordingFinished,
      builder: (context, state) {
        final child = switch (state) {
          RecordingIdle() || RecordingStarting() => null,
          RecordingFailed(:final message) => InfoBar(
            severity: InfoBarSeverity.error,
            title: 'Recording stopped',
            message: message,
            onDismiss: () =>
                context.read<RecordingBloc>().add(const RecordingDismissed()),
          ),
          RecordingActive() ||
          RecordingStopping() => _Transport(partLength: partLength),
          RecordingFinished(:final result) => _SavedPane(
            result: result,
            partLength: partLength,
          ),
        };
        return AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.ease,
          alignment: Alignment.topCenter,
          child: child == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: child,
                ),
        );
      },
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.partLength});

  final Duration partLength;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
    final buttonSize = Size(AppSize.compactButtonWidth, t.controlHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.paneRaised,
            borderRadius: BorderRadius.circular(t.paneRadius),
            border: Border.all(color: paused ? t.seam : t.seamStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TallyDot(live: !paused && !stopping),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      paused ? 'PAUSED' : 'REC',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: paused ? t.inkMuted : t.tallyInk,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: buttonSize),
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
                        minimumSize: buttonSize,
                        backgroundColor: t.tally,
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
                const SizedBox(height: AppSpacing.sm),
                _LiveStatus(partLength: partLength, paused: paused),
              ],
            ),
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InfoBar(severity: InfoBarSeverity.warning, title: warning),
        ],
      ],
    );
  }
}

/// The only widget that rebuilds on every status tick.
class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.partLength, required this.paused});

  final Duration partLength;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final status = context.select<RecordingBloc, RecordingStatus>(
      (b) => switch (b.state) {
        RecordingActive(:final status) => status,
        RecordingStopping(:final lastStatus) => lastStatus,
        _ => RecordingStatus.initial,
      },
    );
    final partsBefore = math.max(0, status.segmentIndex - 1);
    final inPart = status.elapsed - partLength * partsBefore;
    final clamped = inPart.isNegative
        ? Duration.zero
        : (inPart > partLength ? partLength : inPart);
    final small = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: false,
          label: 'Elapsed',
          child: Text(
            formatElapsed(status.elapsed),
            style: theme.textTheme.displaySmall?.copyWith(
              color: paused ? t.inkMuted : t.ink,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PartStrip.live(
          elapsedInPart: clamped,
          partLength: partLength,
          color: paused ? t.inkFaint : t.accent,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Part ${status.segmentIndex} · '
                '${formatBytes(status.bytesWritten)}',
                style: small,
              ),
            ),
            if (partLength > Duration.zero)
              Text(
                'Next part in ${formatElapsed(partLength - clamped)}',
                style: small,
              ),
          ],
        ),
      ],
    );
  }
}

class _SavedPane extends StatelessWidget {
  const _SavedPane({required this.result, required this.partLength});

  final RecordingResult result;
  final Duration partLength;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final bloc = context.read<RecordingBloc>();
    final parts = result.files.length;
    final file = result.files.isEmpty ? null : result.files.first;
    final revealLabel = (UiLook.current == UiLook.mac)
        ? 'Show in Finder'
        : 'Show in Explorer';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.paneRaised,
        borderRadius: BorderRadius.circular(t.paneRadius),
        border: Border.all(color: t.seam),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: t.success,
                  size: AppSize.iconLg,
                ),
                const SizedBox(width: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Recording saved',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (file != null)
              SelectableText(
                fileNameOf(file),
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${formatElapsed(result.duration)} · '
              '${formatBytes(result.bytesWritten)}'
              '${parts > 1 ? ' · $parts parts' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (parts > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              PartStrip.recorded(
                parts: parts,
                duration: result.duration,
                partLength: partLength,
                semanticsLabel: '$parts ${parts == 1 ? 'part' : 'parts'}',
              ),
            ],
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
                TextButton(
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
