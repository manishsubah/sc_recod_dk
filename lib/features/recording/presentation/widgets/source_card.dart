import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
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
                    ],
                    selected: {
                      state.area == null
                          ? _CaptureMode.fullScreen
                          : _CaptureMode.area,
                    },
                    onSelectionChanged: busy
                        ? null
                        : (selection) => switch (selection.first) {
                            _CaptureMode.fullScreen => cubit.useFullScreen(),
                            _CaptureMode.area => cubit.selectArea(),
                          },
                  ),
                  if (state.area case final area?)
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
                      'Choose Area to drag a rectangle on the screen.',
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

enum _CaptureMode { fullScreen, area }

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
