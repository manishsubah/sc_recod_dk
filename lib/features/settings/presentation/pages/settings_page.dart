import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.extraSections = const []});

  /// Cards from other features (e.g. keyboard shortcuts), added by the app shell.
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (_, s) => s.error != null,
      listener: (context, state) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!))),
      child: PageScaffold(
        title: 'Settings',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SaveFolderCard(),
            const SizedBox(height: AppSpacing.md),
            const _RecordingCard(),
            const SizedBox(height: AppSpacing.md),
            const _AppearanceCard(),
            for (final section in extraSections) ...[
              const SizedBox(height: AppSpacing.md),
              section,
            ],
            const SizedBox(height: AppSpacing.md),
            const _ComingNextCard(),
          ],
        ),
      ),
    );
  }
}

class _SaveFolderCard extends StatelessWidget {
  const _SaveFolderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final cubit = context.read<SettingsCubit>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Save recordings to',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  state.outputFolder,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Recordings are saved here as MP4 files.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: cubit.chooseFolder,
                      icon: const Icon(Icons.drive_folder_upload_outlined),
                      label: const Text('Change folder…'),
                    ),
                    if (!state.usesDefaultFolder)
                      TextButton(
                        onPressed: cubit.useDefaultFolder,
                        child: const Text('Use default folder'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ComingNextCard extends StatelessWidget {
  const _ComingNextCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Recording a single app window is coming next.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final options = context.select<SettingsCubit, RecordingOptions>(
      (c) => c.state.options,
    );
    final segment = options.segmentDuration;
    final segmentMinutes =
        segment.inSeconds % 60 == 0 &&
            RecordingDefaults.segmentMinuteChoices.contains(segment.inMinutes)
        ? segment.inMinutes
        : null;

    return _SettingsCard(
      icon: Icons.videocam_outlined,
      title: 'Recording',
      footer: 'Changes apply to the next recording.',
      children: [
        _SettingRow(
          label: 'Split every',
          description: segmentMinutes == null
              ? 'Test mode: ${segment.inSeconds} s parts '
                    '(RECLITE_SEGMENT_SECONDS).'
              : 'Long recordings are saved as parts of this length.',
          control: DropdownButton<int>(
            value: segmentMinutes,
            onChanged: (m) {
              if (m != null) cubit.setSegmentMinutes(m);
            },
            items: [
              for (final m in RecordingDefaults.segmentMinuteChoices)
                DropdownMenuItem(value: m, child: Text('$m minutes')),
            ],
          ),
        ),
        _SettingRow(
          label: 'Quality',
          description: 'Bigger screens are scaled down to this height.',
          control: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final h in RecordingDefaults.maxHeightChoices)
                ButtonSegment(value: h, label: Text('${h}p')),
            ],
            selected: {options.maxHeight},
            onSelectionChanged: (s) => cubit.setMaxHeight(s.single),
          ),
        ),
        _SettingRow(
          label: 'Frame rate',
          description: '60 fps is smoother but makes bigger files.',
          control: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final f in RecordingDefaults.framesPerSecondChoices)
                ButtonSegment(value: f, label: Text('$f fps')),
            ],
            selected: {options.framesPerSecond},
            onSelectionChanged: (s) => cubit.setFramesPerSecond(s.single),
          ),
        ),
        _SettingRow(
          label: 'Mouse pointer',
          description: 'Show the pointer in the video.',
          control: Switch(
            value: options.showCursor,
            onChanged: (show) => cubit.setShowCursor(show: show),
          ),
        ),
        _SettingRow(
          label: 'Mini bar while recording',
          description:
              'Shrink RecLite to a small bar at the top of the screen. '
              'The tray icon also controls the recording.',
          control: Switch(
            value: context.select<SettingsCubit, bool>(
              (c) => c.state.miniBarWhileRecording,
            ),
            onChanged: (on) => cubit.setMiniBarWhileRecording(enabled: on),
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsCubit, AppThemeMode>(
      (c) => c.state.themeMode,
    );
    return _SettingsCard(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      children: [
        _SettingRow(
          label: 'Theme',
          control: SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('System')),
              ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                context.read<SettingsCubit>().setThemeMode(s.single),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.children,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ...children,
            if (footer case final footer?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                footer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.control,
    this.description,
  });

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (description case final description?)
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          control,
        ],
      ),
    );
  }
}
