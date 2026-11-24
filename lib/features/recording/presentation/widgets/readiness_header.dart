import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/info_bar.dart';
import 'package:reclite/core/widgets/tally_dot.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

/// One status line under the page title: ready, recording or paused, where
/// files go and how much room is left.
class ReadinessLine extends StatelessWidget {
  const ReadinessLine({
    super.key,
    required this.canRecord,
    required this.storage,
  });

  final bool canRecord;
  final StorageInfo storage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted);
    final folder = fileNameOf(storage.path);
    // null while idle, true while recording, false while paused or saving.
    final live = context.select<RecordingBloc, bool?>(
      (b) => switch (b.state) {
        final RecordingActive a => !a.isPaused,
        RecordingStopping() => false,
        _ => null,
      },
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Row(
            key: ValueKey(live),
            mainAxisSize: MainAxisSize.min,
            children: [
              switch (live) {
                null => Icon(
                  canRecord ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: AppSize.iconSm,
                  color: canRecord ? t.success : t.danger,
                ),
                final on => TallyDot(live: on, size: AppSize.recordDot),
              },
              const SizedBox(width: AppSpacing.xxs + 2),
              Text(
                switch (live) {
                  null => canRecord ? 'Ready to Record' : 'Not ready to record',
                  true => 'Recording',
                  false => 'Paused',
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: live == true ? t.tallyInk : t.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (storage.path.isNotEmpty) ...[
          Text('·', style: muted),
          Tooltip(
            message: storage.path,
            child: Text(
              'Saves to ${folder.isEmpty ? storage.path : folder}',
              style: muted,
            ),
          ),
        ],
        if (storage.totalBytes > 0) ...[
          Text('·', style: muted),
          Text(
            '${formatBytes(storage.freeBytes)} free',
            style: muted?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Blocking problems and warnings, each as an inline bar.
class ReadinessIssues extends StatelessWidget {
  const ReadinessIssues({super.key, required this.issues});

  final List<ReadinessIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InfoBar(
              severity: issue.isBlocking
                  ? InfoBarSeverity.error
                  : InfoBarSeverity.warning,
              title: issue.message,
            ),
          ),
      ],
    );
  }
}
