import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/constants/app_info.dart';
import 'package:reclite/core/widgets/tally_dot.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

enum AppSection {
  record('Record', Icons.radio_button_checked_rounded),
  history('History', Icons.video_library_outlined),
  settings('Settings', Icons.settings_outlined),
  help('Help', Icons.help_outline_rounded);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Native-style navigation: Windows 11 NavigationView on Windows, a source-list
/// sidebar on macOS. Icons only (with tooltips) when [compact].
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.compact,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.ease,
      width: compact ? AppLayout.navCompactWidth : AppLayout.navWidth,
      color: t.ground,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(compact: compact),
          const SizedBox(height: AppSpacing.xs),
          for (final section in AppSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: _NavItem(
                section: section,
                selected: section == selected,
                compact: compact,
                onTap: () => onSelect(section),
              ),
            ),
          const Spacer(),
          _RecordingStatus(
            compact: compact,
            onTap: () => onSelect(AppSection.record),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (!compact) const SizedBox(width: AppSpacing.xs),
          Semantics(
            label: AppInfo.name,
            image: true,
            child: Image.asset(
              AppInfo.iconAsset,
              width: AppSize.logo,
              height: AppSize.logo,
              excludeFromSemantics: true,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.sm),
            ExcludeSemantics(
              child: Text(AppInfo.name, style: theme.textTheme.titleMedium),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(t.controlRadius);
    final icon = Icon(
      section.icon,
      size: AppSize.iconLg,
      color: selected ? t.accent : t.inkMuted,
    );

    final item = Semantics(
      selected: selected,
      label: compact ? section.label : null,
      child: Material(
        color: selected
            ? (t.isMac ? t.accentTint : t.pressed)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: t.hover,
          focusColor: t.accentTint,
          child: SizedBox(
            height: t.navItemHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (section == AppSection.record)
                    _RecordBadge(child: icon)
                  else
                    icon,
                  if (!compact) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        section.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: selected
                              ? (t.isMac ? FontWeight.w500 : FontWeight.w600)
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: section.label, child: item) : item;
  }
}

/// Red light on the Record icon while a recording runs in the background.
class _RecordBadge extends StatelessWidget {
  const _RecordBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (busy)
          const Positioned(
            right: -2,
            top: -2,
            child: TallyDot(live: true, size: AppSize.recordDot - 2),
          ),
      ],
    );
  }
}

/// "Recording" / "Paused" at the foot of the sidebar, visible from every page.
class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final (busy, paused) = context.select<RecordingBloc, (bool, bool)>(
      (b) => switch (b.state) {
        final RecordingActive a => (true, a.isPaused),
        final s => (s.isBusy, false),
      },
    );
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: !busy
          ? const SizedBox.shrink()
          : Tooltip(
              message: 'Go to the recording',
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(t.controlRadius),
                child: Container(
                  height: t.navItemHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 0 : AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: paused ? t.hover : t.tallyTint,
                    borderRadius: BorderRadius.circular(t.controlRadius),
                  ),
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      TallyDot(live: !paused, size: AppSize.recordDot),
                      if (!compact) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          paused ? 'Paused' : 'Recording',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: paused ? t.inkMuted : t.tallyInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
