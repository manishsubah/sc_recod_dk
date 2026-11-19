import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/di.dart';
import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/history/presentation/pages/history_page.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite/features/recording/presentation/pages/home_page.dart';
import 'package:reclite/features/settings/presentation/pages/settings_page.dart';

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
      ],
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _section.index,
              onDestinationSelected: (i) =>
                  setState(() => _section = AppSection.values[i]),
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
                AppSection.settings => const SettingsPage(),
              },
            ),
          ],
        ),
      ),
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
