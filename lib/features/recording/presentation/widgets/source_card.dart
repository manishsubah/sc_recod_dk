import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/recording/domain/entities/capture_window.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

/// What to record: screen permission prompt or the display picker.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: BlocBuilder<SourcesCubit, SourcesState>(
          builder: (context, state) => switch (state) {
            SourcesLoading() => const _InlineMessage(
              leading: SizedBox.square(
                dimension: AppSize.inlineProgress,
                child: CircularProgressIndicator(
                  strokeWidth: AppSize.progressStroke,
                ),
              ),
              text: 'Looking for displays…',
            ),
            SourcesPermissionRequired(:final requested) => _PermissionPrompt(
              requested: requested,
            ),
            final SourcesLoaded loaded => _DisplayPicker(state: loaded),
            SourcesFailed(:final message) => _InlineMessage(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              text: message,
              action: TextButton(
                onPressed: () => context.read<SourcesCubit>().load(),
                child: const Text('Retry'),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _DisplayPicker extends StatelessWidget {
  const _DisplayPicker({required this.state});

  final SourcesLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    final cubit = context.read<SourcesCubit>();

    return Column(
      children: [
        Row(
          children: [
            _RowLabel(icon: Icons.monitor_outlined, label: 'Screen'),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: state.selectedId,
                underline: const SizedBox.shrink(),
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
            ),
            IconButton(
              tooltip: 'Refresh displays',
              onPressed: busy ? null : cubit.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const _RowLabel(icon: Icons.crop_free, label: 'Record'),
            Expanded(
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_CaptureMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _CaptureMode.fullScreen,
                        icon: Icon(Icons.fullscreen),
                        label: Text('Full screen'),
                      ),
                      ButtonSegment(
                        value: _CaptureMode.area,
                        icon: Icon(Icons.highlight_alt),
                        label: Text('Area'),
                      ),
                      ButtonSegment(
                        value: _CaptureMode.window,
                        icon: Icon(Icons.web_asset),
                        label: Text('Window'),
                      ),
                    ],
                    selected: {
                      state.window != null
                          ? _CaptureMode.window
                          : state.area != null
                          ? _CaptureMode.area
                          : _CaptureMode.fullScreen,
                    },
                    onSelectionChanged: busy
                        ? null
                        : (selection) => switch (selection.first) {
                            _CaptureMode.fullScreen => cubit.useFullScreen(),
                            _CaptureMode.area => cubit.selectArea(),
                            _CaptureMode.window => _pickWindow(context),
                          },
                  ),
                  if (state.window case final window?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppLayout.windowLabelMaxWidth,
                          ),
                          child: Text(
                            window.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => _pickWindow(context),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Change'),
                        ),
                      ],
                    )
                  else if (state.area case final area?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          area.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : cubit.selectArea,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Change'),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Choose Area to drag a rectangle, or Window to record '
                      'one app.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppSize.iconMd,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: AppLayout.labelColumnWidth,
          child: Text(label, style: theme.textTheme.bodyMedium),
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
    final theme = Theme.of(context);
    final cubit = context.read<SourcesCubit>();
    final settingsPath = Platform.isMacOS
        ? 'System Settings → Privacy & Security → Screen & System Audio Recording'
        : 'Settings → Privacy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text('Allow screen recording', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          requested
              ? 'Turn on RecLite in $settingsPath, then quit and reopen RecLite.'
              : 'RecLite needs your permission to record the screen. '
                    'You only have to do this once.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (!requested)
              FilledButton.tonal(
                onPressed: cubit.requestPermission,
                child: const Text('Allow access'),
              ),
            OutlinedButton(
              onPressed: cubit.openPermissionSettings,
              child: const Text('Open System Settings'),
            ),
            TextButton(onPressed: cubit.load, child: const Text('Check again')),
          ],
        ),
      ],
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
    return Row(
      children: [
        leading,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
        ?action,
      ],
    );
  }
}
