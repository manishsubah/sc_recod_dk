import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/di.dart';
import 'package:reclite/app/router/app_sidebar.dart';
import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';
import 'package:reclite/features/help/presentation/bloc/help_cubit.dart';
import 'package:reclite/features/help/presentation/pages/help_page.dart';
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
        BlocProvider<HelpCubit>(create: (_) => getIt<HelpCubit>()),
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

  void _select(BuildContext context, AppSection section) {
    if (section == AppSection.history) {
      context.read<HistoryCubit>().refresh();
    }
    setState(() => _section = section);
  }

  Widget _buildScaffold(BuildContext context) {
    final t = context.tokens;
    final compact =
        MediaQuery.sizeOf(context).width < AppLayout.navCompactBreakpoint;
    final page = AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.ease,
      switchOutCurve: AppMotion.ease,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: switch (_section) {
          AppSection.record => const HomePage(),
          AppSection.history => const HistoryPage(),
          AppSection.settings => const SettingsPage(
            extraSections: [ShortcutsCard()],
          ),
          AppSection.help => const HelpPage(),
        },
      ),
    );

    return Scaffold(
      backgroundColor: t.ground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSidebar(
            selected: _section,
            compact: compact,
            onSelect: (s) => _select(context, s),
          ),
          Expanded(
            // Windows 11: content sits on a layer with a rounded top-left corner;
            // macOS: a plain content area beside the sidebar.
            child: t.isMac
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.pane,
                      border: Border(left: BorderSide(color: t.seam)),
                    ),
                    child: page,
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.pane,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.lg),
                        ),
                        border: Border(
                          top: BorderSide(color: t.seam),
                          left: BorderSide(color: t.seam),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.lg),
                        ),
                        child: page,
                      ),
                    ),
                  ),
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
