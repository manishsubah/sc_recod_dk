import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

enum InfoBarSeverity { info, success, warning, error }

/// An inline message across the content, like Windows' InfoBar: a tinted
/// strip with an icon, a short title, a message and optional actions.
class InfoBar extends StatelessWidget {
  const InfoBar({
    super.key,
    required this.severity,
    required this.title,
    this.message,
    this.actions = const [],
    this.onDismiss,
  });

  final InfoBarSeverity severity;
  final String title;
  final String? message;
  final List<Widget> actions;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final (icon, color) = switch (severity) {
      InfoBarSeverity.info => (Icons.info_rounded, t.accent),
      InfoBarSeverity.success => (Icons.check_circle_rounded, t.success),
      InfoBarSeverity.warning => (Icons.warning_rounded, t.warning),
      InfoBarSeverity.error => (Icons.error_rounded, t.danger),
    };

    return Semantics(
      liveRegion: severity == InfoBarSeverity.error,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.09), t.paneRaised),
          borderRadius: BorderRadius.circular(t.paneRadius),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: AppSize.iconLg, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (message != null)
                      Text(
                        message!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.inkMuted,
                        ),
                      ),
                    if (actions.isNotEmpty)
                      Wrap(spacing: AppSpacing.xxs, children: actions),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  iconSize: AppSize.iconMd,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
