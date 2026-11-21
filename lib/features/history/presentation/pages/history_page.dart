import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/coming_soon.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HistoryCubit, HistoryState>(
      listenWhen: (_, s) => s is HistoryLoaded && s.error != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text((state as HistoryLoaded).error!))),
      child: PageScaffold(
        title: 'History',
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) => switch (state) {
            HistoryLoading() => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            HistoryFailed(:final message) => _FailedView(message: message),
            final HistoryLoaded loaded => _LoadedView(state: loaded),
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final HistoryLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.recordings.isEmpty
                    ? state.folder
                    : '${state.recordings.length} in ${state.folder}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: context.read<HistoryCubit>().refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (state.recordings.isEmpty)
          const ComingSoon(
            icon: Icons.video_library_outlined,
            title: 'No recordings yet',
            description:
                'Your recordings will appear here with date, duration, size '
                'and location.',
          )
        else
          for (final recording in state.recordings) ...[
            _RecordingTile(recording: recording),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final SavedRecording recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HistoryCubit>();
    final parts = recording.files.length;
    final details = [
      formatElapsed(recording.duration),
      formatBytes(recording.bytes),
      if (parts > 1) '$parts parts',
      if (recording.sourceName.isNotEmpty) recording.sourceName,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.movie_outlined,
              size: AppSize.iconXl,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          formatDateTime(recording.startedAt),
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recording.outcome != RecordingOutcome.completed) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _OutcomeChip(outcome: recording.outcome),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: parts > 1 ? 'Play part 1' : 'Play',
              onPressed: () => cubit.play(recording),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: Platform.isMacOS ? 'Show in Finder' : 'Show in folder',
              onPressed: () => cubit.reveal(recording),
              icon: const Icon(Icons.folder_open_outlined),
            ),
            IconButton(
              tooltip: _trashLabel,
              onPressed: () => _confirmTrash(context, cubit),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  static String get _trashLabel =>
      Platform.isMacOS ? 'Move to Trash' : 'Move to Recycle Bin';

  Future<void> _confirmTrash(BuildContext context, HistoryCubit cubit) async {
    final parts = recording.files.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$_trashLabel?'),
        content: Text(
          'The recording from ${formatDateTime(recording.startedAt)}'
          '${parts > 1 ? ' ($parts parts)' : ''} will be moved to the '
          '${Platform.isMacOS ? 'Trash' : 'Recycle Bin'}. You can restore it '
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

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome});

  final RecordingOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (outcome) {
      RecordingOutcome.recovered => ('Recovered', AppColors.warning),
      _ => ('Interrupted', theme.colorScheme.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.none,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: AppSize.iconXxl,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.read<HistoryCubit>().load(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
