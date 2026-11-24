import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// An empty state that teaches what will appear here and how to get it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.paneRadius),
        border: Border.all(color: t.seam),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.huge,
        ),
        child: Column(
          children: [
            Icon(icon, size: AppSize.iconXxl, color: t.inkMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
