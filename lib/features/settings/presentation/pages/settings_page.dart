import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/core/widgets/pane.dart';
import 'package:reclite/core/widgets/select_box.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.extraSections = const []});

  /// Panes from other features (e.g. keyboard shortcuts), added by the app
  /// shell.
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
            const _StoragePane(),
            const SizedBox(height: AppSpacing.xl),
            const _RecordingPane(),
            const SizedBox(height: AppSpacing.xl),
            const _AppearancePane(),
            for (final section in extraSections) ...[
              const SizedBox(height: AppSpacing.xl),
              section,
            ],
          ],
        ),
      ),
    );
  }
}

class _StoragePane extends StatelessWidget {
  const _StoragePane();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return Pane(
          title: 'Storage',
          children: [
            PaneRow(
              icon: Icons.folder_outlined,
              label: 'Save recordings to',
              description: const Text(
                'Recordings are saved here as MP4 files.',
              ),
              control: OutlinedButton(
                onPressed: cubit.chooseFolder,
                child: const Text('Change folder…'),
              ),
              below: Padding(
                padding: const EdgeInsets.only(
                  left: AppSize.iconLg + AppSpacing.sm,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: t.pane,
                    borderRadius: BorderRadius.circular(t.controlRadius),
                    border: Border.all(color: t.seam),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          state.outputFolder,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: t.ink,
                          ),
                        ),
                      ),
                      if (!state.usesDefaultFolder)
                        TextButton(
                          onPressed: cubit.useDefaultFolder,
                          child: const Text('Use default folder'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordingPane extends StatelessWidget {
  const _RecordingPane();

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

    return Pane(
      title: 'Recording',
      footer: 'Changes apply to the next recording.',
      children: [
        PaneRow(
          label: 'Split every',
          description: Text(
            segmentMinutes == null
                ? 'Test mode: ${segment.inSeconds} s parts '
                      '(RECLITE_SEGMENT_SECONDS).'
                : 'Long recordings are saved as parts of this length.',
          ),
          control: SelectBox<int>(
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
        PaneRow(
          label: 'Quality',
          description: const Text(
            'Bigger screens are scaled down to this height.',
          ),
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
        PaneRow(
          label: 'Frame rate',
          description: const Text('60 fps is smoother but makes bigger files.'),
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
        PaneRow(
          label: 'Mouse pointer',
          description: const Text('Show the pointer in the video.'),
          control: Switch(
            value: options.showCursor,
            onChanged: (show) => cubit.setShowCursor(show: show),
          ),
        ),
        PaneRow(
          label: 'Mini bar while recording',
          description: const Text(
            'Shrink RecLite to a small bar at the top of the screen. '
            'The tray icon also controls the recording.',
          ),
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

class _AppearancePane extends StatelessWidget {
  const _AppearancePane();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsCubit, AppThemeMode>(
      (c) => c.state.themeMode,
    );
    return Pane(
      title: 'Appearance',
      children: [
        PaneRow(
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
