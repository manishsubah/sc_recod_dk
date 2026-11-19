import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';

/// "We saved your last recording" after a crash or power loss.
class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecoveryCubit, RecoveryState>(
      builder: (context, state) => switch (state) {
        RecoveryIdle() => const SizedBox.shrink(),
        RecoveryFound(:final recordings) => _Banner(
          count: recordings.length,
          duration: recordings.fold(
            Duration.zero,
            (sum, r) => sum + r.duration,
          ),
          folder: recordings.last.sessionDirectory,
        ),
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.count,
    required this.duration,
    required this.folder,
  });

  final int count;
  final Duration duration;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<RecoveryCubit>();
    final what = count == 1 ? 'a recording' : '$count recordings';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.restore, color: scheme.onSecondaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RecLite recovered $what',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'It was interrupted before it finished. '
                      '${formatElapsed(duration)} was saved.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => cubit.reveal(folder),
                child: Text(Platform.isMacOS ? 'Show in Finder' : 'Show'),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: cubit.dismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
