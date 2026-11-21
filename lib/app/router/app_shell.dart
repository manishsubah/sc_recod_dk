import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/di.dart';
import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';
import 'package:reclite/features/history/presentation/pages/history_page.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite/features/recording/presentation/pages/home_page.dart';
import 'package:reclite/features/recording/presentation/recording_start.dart';
import 'package:reclite/features/recording/presentation/widgets/mini_recording_bar.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:reclite/features/settings/presentation/pages/settings_page.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/presentation/bloc/shortcuts_cubit.dart';
import 'package:reclite/features/shortcuts/presentation/widgets/shortcuts_card.dart';

enum AppSection {
  record(
    'Record',
    Icons.radio_button_checked_outlined,
    Icons.radio_button_checked,
  ),
  history('History', Icons.video_library_outlined, Icons.video_library),
  settings('Settings', Icons.settings_outlined, Icons.settings);

  const AppSection(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.record;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ReadinessCubit>(
          create: (_) => getIt<ReadinessCubit>()..load(),
        ),
        BlocProvider<SourcesCubit>(
          create: (_) => getIt<SourcesCubit>()..load(),
        ),
        BlocProvider<AudioCubit>(create: (_) => getIt<AudioCubit>()),
        BlocProvider<AudioLevelsCubit>(
          create: (_) => getIt<AudioLevelsCubit>(),
        ),
        BlocProvider<RecordingBloc>(create: (_) => getIt<RecordingBloc>()),
        BlocProvider<RecoveryCubit>(
          create: (_) => getIt<RecoveryCubit>()..check(),
          lazy: false,
        ),
        BlocProvider<HistoryCubit>(
          create: (_) => getIt<HistoryCubit>()..load(),
        ),
        BlocProvider<WindowModeCubit>(
          create: (_) =>
              getIt<WindowModeCubit>()..showTrayStatus(TrayStatus.idle),
          lazy: false,
        ),
        BlocProvider<ShortcutsCubit>(
          create: (_) => getIt<ShortcutsCubit>()..start(),
          lazy: false,
        ),
      ],
      child: _FeatureLinks(
        child: Builder(
          builder: (context) =>
              context.select<WindowModeCubit, bool>(
                (c) => c.state == WindowMode.mini,
              )
              ? MiniRecordingBar(
                  onExpand: context.read<WindowModeCubit>().showFull,
                  onDragStart: context.read<WindowModeCubit>().startDrag,
                )
              : _buildScaffold(context),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _section.index,
            onDestinationSelected: (i) {
              final section = AppSection.values[i];
              if (section == AppSection.history) {
                context.read<HistoryCubit>().refresh();
              }
              setState(() => _section = section);
            },
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: _Logo(),
            ),
            destinations: [
              for (final s in AppSection.values)
                NavigationRailDestination(
                  icon: s == AppSection.record
                      ? _RecordingBadge(child: Icon(s.icon))
                      : Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
                  label: Text(s.label),
                ),
            ],
          ),
          const VerticalDivider(width: AppSize.hairline),
          Expanded(
            child: switch (_section) {
              AppSection.record => const HomePage(),
              AppSection.history => const HistoryPage(),
              AppSection.settings => const SettingsPage(
                extraSections: [ShortcutsCard()],
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Passes changes between features: a new save folder reaches the recorder and
/// History, and a finished recording appears in History.
class _FeatureLinks extends StatefulWidget {
  const _FeatureLinks({required this.child});

  final Widget child;

  @override
  State<_FeatureLinks> createState() => _FeatureLinksState();
}

class _FeatureLinksState extends State<_FeatureLinks> {
  StreamSubscription<ShortcutAction>? _shortcuts;
  StreamSubscription<TrayCommand>? _tray;

  @override
  void initState() {
    super.initState();
    _shortcuts = context.read<ShortcutsCubit>().pressed.listen(_onShortcut);
    _tray = context.read<WindowModeCubit>().trayCommands.listen(_onTray);
  }

  @override
  void dispose() {
    unawaited(_shortcuts?.cancel());
    unawaited(_tray?.cancel());
    super.dispose();
  }

  void _onTray(TrayCommand command) => switch (command) {
    TrayCommand.startStop => _onShortcut(ShortcutAction.startStop),
    TrayCommand.pauseResume => _onShortcut(ShortcutAction.pauseResume),
    TrayCommand.showWindow => context.read<WindowModeCubit>().showFull(),
  };

  static TrayStatus _trayStatusFor(RecordingState state) => switch (state) {
    RecordingActive(isPaused: true) => TrayStatus.paused,
    RecordingStarting() ||
    RecordingActive() ||
    RecordingStopping() => TrayStatus.recording,
    _ => TrayStatus.idle,
  };

  void _onShortcut(ShortcutAction action) {
    final bloc = context.read<RecordingBloc>();
    final state = bloc.state;
    switch (action) {
      case ShortcutAction.startStop:
        if (state is RecordingActive) {
          bloc.add(const RecordingStopRequested());
        } else if (!state.isBusy) {
          final config = currentRecordingConfig(context);
          if (config != null) bloc.add(RecordingStartRequested(config));
        }
      case ShortcutAction.pauseResume:
        if (state is RecordingActive) {
          bloc.add(
            state.isPaused
                ? const RecordingResumeRequested()
                : const RecordingPauseRequested(),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (a, b) => a.outputFolder != b.outputFolder,
          listener: (context, state) {
            final folder = state.outputFolder;
            context.read<ReadinessCubit>().changeFolder(folder);
            context.read<RecoveryCubit>().check(folder: folder);
            context.read<HistoryCubit>().load(folder);
          },
        ),
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (a, b) => a.options != b.options,
          listener: (context, state) =>
              context.read<ReadinessCubit>().changeOptions(state.options),
        ),
        BlocListener<RecordingBloc, RecordingState>(
          listener: (context, state) {
            final window = context.read<WindowModeCubit>();
            window.showTrayStatus(_trayStatusFor(state));
            if (state is RecordingActive &&
                context.read<SettingsCubit>().state.miniBarWhileRecording) {
              window.showMini();
            } else if (!state.isBusy) {
              window.showFull();
            }
          },
          listenWhen: (a, b) =>
              a.runtimeType != b.runtimeType ||
              _trayStatusFor(a) != _trayStatusFor(b),
        ),
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (_, s) => s is RecordingFinished,
          listener: (context, _) => context.read<HistoryCubit>().refresh(),
        ),
      ],
      child: widget.child,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'RecLite',
      child: Container(
        width: AppSize.logo,
        height: AppSize.logo,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.videocam_rounded, color: scheme.onPrimary),
      ),
    );
  }
}

/// Red dot on the Record section while a recording runs in the background.
class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    return Badge(
      isLabelVisible: busy,
      backgroundColor: AppColors.recording,
      smallSize: AppSize.recordDot,
      child: child,
    );
  }
}
