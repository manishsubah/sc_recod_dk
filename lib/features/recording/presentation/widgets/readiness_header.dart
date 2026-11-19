import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';

class ReadinessHeader extends StatelessWidget {
  const ReadinessHeader({
    super.key,
    required this.canRecord,
    required this.issues,
  });

  final bool canRecord;
  final List<ReadinessIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canRecord ? Icons.check_circle : Icons.error,
                  color: canRecord ? AppColors.success : scheme.error,
                  size: AppSize.iconXl,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canRecord ? 'Ready to Record' : 'Not ready to record',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        canRecord
                            ? 'Record your screen with just one click.'
                            : 'Fix the issue below to start recording.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            for (final issue in issues) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isBlocking
                        ? Icons.block
                        : Icons.warning_amber_rounded,
                    size: AppSize.iconMd,
                    color: issue.isBlocking ? scheme.error : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(issue.message)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
