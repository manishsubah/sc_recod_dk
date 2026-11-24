import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/edge_label.dart';
import 'package:reclite/core/widgets/empty_state.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/core/widgets/part_strip.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HistoryCubit, HistoryState>(
      listenWhen: (_, s) => s is HistoryLoaded && s.error != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text((state as HistoryLoaded).error!))),
      child: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) => PageScaffold(
          title: 'History',
          subtitle: switch (state) {
            HistoryLoaded(:final recordings) when recordings.isNotEmpty => Text(
              _summary(recordings),
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            _ => null,
          },
          action: OutlinedButton.icon(
            onPressed: context.read<HistoryCubit>().refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          child: switch (state) {
            HistoryLoading() => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            HistoryFailed(:final message) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'History could not be read',
              description: message,
              action: OutlinedButton(
                onPressed: () => context.read<HistoryCubit>().load(),
                child: const Text('Try again'),
              ),
            ),
            HistoryLoaded(:final recordings) when recordings.isEmpty =>
              const EmptyState(
                icon: Icons.video_library_outlined,
                title: 'No recordings yet',
                description:
                    'Your recordings will appear here with date, duration, '
                    'size and location.',
              ),
            final HistoryLoaded loaded => _RecordingList(
              recordings: loaded.recordings,
            ),
          },
        ),
      ),
    );
  }

  static String _summary(List<SavedRecording> recordings) {
    final n = recordings.length;
    final total = recordings.fold(Duration.zero, (sum, r) => sum + r.duration);
    final bytes = recordings.fold(0, (sum, r) => sum + r.bytes);
    return '${n == 1 ? '1 recording' : '$n recordings'} · '
        '${formatElapsed(total)} · ${formatBytes(bytes)}';
  }
}

/// One table-like list: rows divided by seams, columns that drop away on a
/// narrow window.
class _RecordingList extends StatelessWidget {
  const _RecordingList({required this.recordings});

  final List<SavedRecording> recordings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppLayout.historyColumnsBreakpoint;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.paneRaised,
            borderRadius: BorderRadius.circular(t.paneRadius),
            border: Border.all(color: t.seam),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.paneRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  const _HeaderRow(),
                  Divider(height: AppSize.hairline, color: t.seam),
                ],
                for (var i = 0; i < recordings.length; i++) ...[
                  if (i > 0) Divider(height: AppSize.hairline, color: t.seam),
                  _RecordingRow(recording: recordings[i], wide: wide),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Container(
        color: t.pane,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: const Row(
          children: [
            Expanded(child: EdgeLabel('Recorded')),
            SizedBox(
              width: AppLayout.historyDurationColumn,
              child: EdgeLabel('Length'),
            ),
            SizedBox(
              width: AppLayout.historySizeColumn,
              child: EdgeLabel('Size'),
            ),
            SizedBox(
              width: AppLayout.historyPartsColumn,
              child: EdgeLabel('Parts'),
            ),
            SizedBox(width: _RecordingRow.actionsWidth),
          ],
        ),
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.recording, required this.wide});

  final SavedRecording recording;
  final bool wide;

  /// Play, Show, the gap and Trash.
  static const double actionsWidth =
      AppSize.iconButton * 3 + AppSpacing.md + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final cubit = context.read<HistoryCubit>();
    final parts = recording.files.length;
    final partLength = context.select<SettingsCubit, Duration>(
      (c) => c.state.options.segmentDuration,
    );
    final numbers = theme.textTheme.bodyMedium?.copyWith(
      color: t.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondary = [
      if (!wide) ...[
        formatElapsed(recording.duration),
        formatBytes(recording.bytes),
        if (parts > 1) '$parts parts',
      ],
      if (recording.sourceName.isNotEmpty) recording.sourceName,
    ].join(' · ');

    return InkWell(
      onDoubleTap: () => cubit.play(recording),
      hoverColor: t.hover,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.xs,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          formatDateTime(recording.startedAt),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: t.ink,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recording.outcome != RecordingOutcome.completed) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _OutcomeStamp(outcome: recording.outcome),
                      ],
                    ],
                  ),
                  if (secondary.isNotEmpty)
                    Text(
                      secondary,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (wide) ...[
              SizedBox(
                width: AppLayout.historyDurationColumn,
                child: Text(formatElapsed(recording.duration), style: numbers),
              ),
              SizedBox(
                width: AppLayout.historySizeColumn,
                child: Text(formatBytes(recording.bytes), style: numbers),
              ),
              SizedBox(
                width: AppLayout.historyPartsColumn,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Tooltip(
                    message: parts == 1 ? '1 part' : '$parts parts',
                    child: PartStrip.recorded(
                      parts: parts,
                      duration: recording.duration,
                      partLength: partLength,
                      color: t.inkMuted,
                      semanticsLabel: parts == 1 ? '1 part' : '$parts parts',
                    ),
                  ),
                ),
              ),
            ],
            IconButton(
              tooltip: parts > 1 ? 'Play part 1' : 'Play',
              onPressed: parts == 0 ? null : () => cubit.play(recording),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: UiLook.current == UiLook.mac
                  ? 'Show in Finder'
                  : 'Show in folder',
              onPressed: () => cubit.reveal(recording),
              icon: const Icon(Icons.folder_open_outlined),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              height: AppSize.iconLg,
              child: VerticalDivider(width: AppSpacing.md, color: t.seam),
            ),
            IconButton(
              tooltip: _trashLabel,
              onPressed: () => _confirmTrash(context, cubit),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  static String get _trashLabel =>
      UiLook.current == UiLook.mac ? 'Move to Trash' : 'Move to Recycle Bin';

  Future<void> _confirmTrash(BuildContext context, HistoryCubit cubit) async {
    final parts = recording.files.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$_trashLabel?'),
        content: Text(
          'The recording from ${formatDateTime(recording.startedAt)}'
          '${parts > 1 ? ' ($parts parts)' : ''} will be moved to the '
          '${UiLook.current == UiLook.mac ? 'Trash' : 'Recycle Bin'}. You can restore it '
          'from there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.moveToTrash(recording);
  }
}

/// A stamped state, like a lab's mark on a can of film.
class _OutcomeStamp extends StatelessWidget {
  const _OutcomeStamp({required this.outcome});

  final RecordingOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, color, hint) = switch (outcome) {
      RecordingOutcome.recovered => (
        'Recovered',
        t.warning,
        'Repaired after RecLite closed unexpectedly',
      ),
      _ => ('Interrupted', t.danger, 'Stopped early and not repaired'),
    };
    return Tooltip(
      message: hint,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs + 2),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: EdgeLabel(label, color: color),
      ),
    );
  }
}
