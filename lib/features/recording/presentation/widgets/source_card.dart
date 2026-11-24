import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/widgets/pane.dart';
import 'package:reclite/core/widgets/select_box.dart';
import 'package:reclite/features/recording/domain/entities/capture_window.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

/// What to record: screen permission prompt or the display and capture picker.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocBuilder<SourcesCubit, SourcesState>(
      builder: (context, state) => switch (state) {
        SourcesLoading() => const Pane(
          title: 'Source',
          children: [
            _InlineMessage(
              leading: SizedBox.square(
                dimension: AppSize.inlineProgress,
                child: CircularProgressIndicator(
                  strokeWidth: AppSize.progressStroke,
                ),
              ),
              text: 'Looking for displays…',
            ),
          ],
        ),
        SourcesPermissionRequired(:final requested) => Pane(
          title: 'Source',
          children: [_PermissionPrompt(requested: requested)],
        ),
        final SourcesLoaded loaded => _DisplayPicker(state: loaded),
        SourcesFailed(:final message) => Pane(
          title: 'Source',
          children: [
            _InlineMessage(
              leading: Icon(
                Icons.error_outline_rounded,
                size: AppSize.iconLg,
                color: t.danger,
              ),
              text: message,
              action: TextButton(
                onPressed: () => context.read<SourcesCubit>().load(),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _DisplayPicker extends StatelessWidget {
  const _DisplayPicker({required this.state});

  final SourcesLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    final cubit = context.read<SourcesCubit>();
    final mode = state.window != null
        ? _CaptureMode.window
        : state.area != null
        ? _CaptureMode.area
        : _CaptureMode.fullScreen;

    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: t.ink,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget detail = switch (mode) {
      _CaptureMode.window => _Detail(
        text: state.window!.label,
        style: detailStyle,
        onChange: busy ? null : () => _pickWindow(context),
      ),
      _CaptureMode.area => _Detail(
        text: state.area!.label,
        style: detailStyle,
        onChange: busy ? null : cubit.selectArea,
      ),
      _CaptureMode.fullScreen => Text(
        'Choose Area to drag a rectangle, or Window to record one app.',
        style: theme.textTheme.bodySmall,
      ),
    };

    return Pane(
      title: 'Source',
      children: [
        PaneRow(
          icon: Icons.monitor_outlined,
          label: 'Screen',
          enabled: !busy,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectBox<int>(
                width: AppLayout.displayPickerWidth,
                value: state.selectedId,
                items: [
                  for (final d in state.displays)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        d.isMain ? '${d.label} · Main' : d.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (id) {
                        if (id != null) cubit.select(id);
                      },
              ),
              const SizedBox(width: AppSpacing.xxs),
              IconButton(
                tooltip: 'Refresh displays',
                onPressed: busy ? null : cubit.load,
                iconSize: AppSize.iconMd,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        PaneRow(
          icon: Icons.crop_free_rounded,
          label: 'Capture',
          enabled: !busy,
          control: SegmentedButton<_CaptureMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _CaptureMode.fullScreen,
                label: Text('Full screen'),
              ),
              ButtonSegment(value: _CaptureMode.area, label: Text('Area')),
              ButtonSegment(value: _CaptureMode.window, label: Text('Window')),
            ],
            selected: {mode},
            onSelectionChanged: busy
                ? null
                : (selection) => switch (selection.first) {
                    _CaptureMode.fullScreen => cubit.useFullScreen(),
                    _CaptureMode.area => cubit.selectArea(),
                    _CaptureMode.window => _pickWindow(context),
                  },
          ),
          below: Padding(
            padding: const EdgeInsets.only(
              left: AppSize.iconLg + AppSpacing.sm,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(key: ValueKey(mode), child: detail),
            ),
          ),
        ),
      ],
    );
  }
}

/// The chosen area or window, with a way to change it.
class _Detail extends StatelessWidget {
  const _Detail({required this.text, required this.style, this.onChange});

  final String text;
  final TextStyle? style;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(text, overflow: TextOverflow.ellipsis, style: style),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(onPressed: onChange, child: const Text('Change')),
      ],
    );
  }
}

enum _CaptureMode { fullScreen, area, window }

Future<void> _pickWindow(BuildContext context) async {
  final cubit = context.read<SourcesCubit>();
  final windows = await cubit.availableWindows();
  if (!context.mounted) return;
  final chosen = await showDialog<CaptureWindow>(
    context: context,
    builder: (context) => _WindowPickerDialog(windows: windows),
  );
  if (chosen != null) cubit.selectWindow(chosen);
}

class _WindowPickerDialog extends StatelessWidget {
  const _WindowPickerDialog({required this.windows});

  final List<CaptureWindow> windows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Record a window'),
      content: SizedBox(
        width: AppLayout.windowPickerWidth,
        child: windows.isEmpty
            ? const Text(
                'No windows to record. Open the app you want to record '
                '(not minimized) and try again.',
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final w in windows)
                    ListTile(
                      leading: const Icon(Icons.web_asset),
                      title: Text(w.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          if (w.appName.isNotEmpty) w.appName,
                          '${w.width} × ${w.height}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.pop(context, w),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.requested});

  final bool requested;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final cubit = context.read<SourcesCubit>();
    final settingsPath = (UiLook.current == UiLook.mac)
        ? 'System Settings → Privacy & Security → Screen & System Audio Recording'
        : 'Settings → Privacy';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: AppSize.iconLg,
                color: t.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Allow screen recording',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            requested
                ? 'Turn on RecLite in $settingsPath, then quit and reopen RecLite.'
                : 'RecLite needs your permission to record the screen. '
                      'You only have to do this once.',
            style: theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (!requested)
                FilledButton(
                  onPressed: cubit.requestPermission,
                  child: const Text('Allow access'),
                ),
              OutlinedButton(
                onPressed: cubit.openPermissionSettings,
                child: const Text('Open System Settings'),
              ),
              TextButton(
                onPressed: cubit.load,
                child: const Text('Check again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.leading,
    required this.text,
    this.action,
  });

  final Widget leading;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
          ?action,
        ],
      ),
    );
  }
}
