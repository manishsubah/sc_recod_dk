import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// A titled group of rows, like a Windows Settings group or a macOS grouped
/// form: one rounded pane, rows divided by 1 px seams (never a stack of cards).
class Pane extends StatelessWidget {
  const Pane({
    super.key,
    required this.children,
    this.title,
    this.trailing,
    this.footer,
  });

  final String? title;

  /// Shown at the right of the title, e.g. a refresh button or a switch.
  final Widget? trailing;
  final List<Widget> children;

  /// Small note under the pane.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: AppSize.hairline, color: t.seam));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title!, style: theme.textTheme.titleSmall),
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.paneRaised,
            borderRadius: BorderRadius.circular(t.paneRadius),
            border: Border.all(color: t.seam),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.paneRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              top: AppSpacing.xs,
            ),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// One row in a [Pane]: optional leading icon, a label (with an optional
/// description under it) and the control at the right.
class PaneRow extends StatelessWidget {
  const PaneRow({
    super.key,
    required this.label,
    this.icon,
    this.description,
    this.control,
    this.below,
    this.enabled = true,
  });

  final IconData? icon;
  final String label;

  /// Secondary line under the label; a widget so it can hold a link.
  final Widget? description;
  final Widget? control;

  /// Full-width content under the row (e.g. a hint with an action).
  final Widget? below;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: t.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppSize.iconLg,
                    color: enabled ? t.inkMuted : t.inkFaint,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: enabled ? t.ink : t.inkMuted,
                        ),
                      ),
                      if (description != null)
                        DefaultTextStyle.merge(
                          style: theme.textTheme.bodySmall,
                          child: description!,
                        ),
                    ],
                  ),
                ),
                if (control != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  control!,
                ],
              ],
            ),
            if (below != null) ...[
              const SizedBox(height: AppSpacing.xs),
              below!,
            ],
          ],
        ),
      ),
    );
  }
}
