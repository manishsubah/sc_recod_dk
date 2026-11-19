import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/di.dart';
import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/history/presentation/pages/history_page.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
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
    return BlocProvider<ReadinessCubit>(
      create: (_) => getIt<ReadinessCubit>()..load(),
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
                    icon: Icon(s.icon),
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
