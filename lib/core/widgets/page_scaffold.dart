import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// A page in the content layer: title row (with an optional status line under
/// the title and the page's main action at the right), then the content,
/// width-limited and scrollable.
class PageScaffold extends StatefulWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.maxContentWidth = AppLayout.contentMaxWidth,
  });

  final String title;

  /// One line under the title: status or a count.
  final Widget? subtitle;

  /// Shown at the right of the title, e.g. the page's main button.
  final Widget? action;
  final Widget child;

  /// Width limit for [child]; the title row always spans the full content
  /// width so page titles line up across sections.
  final double maxContentWidth;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  // The scrollbar must share the scroll view's controller: on desktop a
  // SingleChildScrollView doesn't use the PrimaryScrollController, so a
  // controller-less Scrollbar has no position and asserts when it fades out.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final horizontal = t.isMac ? AppSpacing.xl : AppSpacing.xxl;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final action = widget.action;
    return Scrollbar(
      controller: _scroll,
      // Desktop adds its own scrollbar to every scroll view; this page already
      // has one, so the automatic one is turned off.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            t.isMac ? AppSpacing.lg : AppSpacing.xl,
            horizontal,
            AppSpacing.xxl,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              DefaultTextStyle.merge(
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: t.inkMuted,
                                ),
                                child: subtitle,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        action,
                      ],
                    ],
                  ),
                  SizedBox(height: t.isMac ? AppSpacing.lg : AppSpacing.xl),
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.maxContentWidth,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
