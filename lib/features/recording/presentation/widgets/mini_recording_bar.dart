import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/tally_dot.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

/// The whole window while recording in mini mode: status, Pause/Resume, Stop
/// and a button back to the full window. Dragging the status moves the window.
class MiniRecordingBar extends StatelessWidget {
  const MiniRecordingBar({
    super.key,
    required this.onExpand,
    required this.onDragStart,
  });

  final VoidCallback onExpand;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final bloc = context.read<RecordingBloc>();
    final (paused, stopping) = context.select<RecordingBloc, (bool, bool)>(
      (b) => switch (b.state) {
        final RecordingActive a => (a.isPaused, false),
        RecordingStopping() => (false, true),
        _ => (false, false),
      },
    );
    final accent = paused || stopping ? t.inkMuted : t.tallyInk;
    const compact = VisualDensity.compact;

    return Material(
      color: t.paneRaised,
      shape: Border(top: BorderSide(color: t.seam)),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (_) => onDragStart(),
                child: Row(
                  children: [
                    TallyDot(live: !paused && !stopping),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      stopping
                          ? 'SAVING'
                          : paused
                          ? 'PAUSED'
                          : 'REC',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Flexible(child: _Elapsed()),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: compact,
              tooltip: paused ? 'Resume' : 'Pause',
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
            ),
            IconButton(
              visualDensity: compact,
              tooltip: 'Stop',
              color: t.tallyInk,
              onPressed: stopping
                  ? null
                  : () => bloc.add(const RecordingStopRequested()),
              icon: const Icon(Icons.stop_rounded),
            ),
            IconButton(
              visualDensity: compact,
              tooltip: 'Open RecLite',
              onPressed: onExpand,
              icon: const Icon(Icons.open_in_full_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Elapsed extends StatelessWidget {
  const _Elapsed();

  @override
  Widget build(BuildContext context) {
    final status = context.select<RecordingBloc, RecordingStatus>(
      (b) => switch (b.state) {
        RecordingActive(:final status) => status,
        RecordingStopping(:final lastStatus) => lastStatus,
        _ => RecordingStatus.initial,
      },
    );
    final theme = Theme.of(context);
    return Text(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      status.segmentIndex > 1
          ? '${formatElapsed(status.elapsed)} · Part ${status.segmentIndex}'
          : formatElapsed(status.elapsed),
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
