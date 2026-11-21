import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/utils/formatters.dart';
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
    final bloc = context.read<RecordingBloc>();
    final (paused, stopping) = context.select<RecordingBloc, (bool, bool)>(
      (b) => switch (b.state) {
        final RecordingActive a => (a.isPaused, false),
        RecordingStopping() => (false, true),
        _ => (false, false),
      },
    );
    final accent = paused ? AppColors.warning : AppColors.recording;
    const compact = VisualDensity.compact;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (_) => onDragStart(),
                child: Row(
                  children: [
                    Container(
                      width: AppSize.recordDot,
                      height: AppSize.recordDot,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
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
              color: AppColors.recording,
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
      style: theme.textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
