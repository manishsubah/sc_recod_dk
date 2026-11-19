import 'package:flutter/material.dart';

import '../bloc/readiness_cubit.dart';

/// "Ready to Record" status card with any blocking issues or warnings.
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
    final ok = Colors.green.shade600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canRecord ? Icons.check_circle : Icons.error,
                  color: canRecord ? ok : scheme.error,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canRecord ? 'Ready to Record' : 'Not ready to record',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isBlocking
                        ? Icons.block
                        : Icons.warning_amber_rounded,
                    size: 20,
                    color: issue.isBlocking ? scheme.error : Colors.orange,
                  ),
                  const SizedBox(width: 10),
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
