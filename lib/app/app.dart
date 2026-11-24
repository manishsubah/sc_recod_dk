import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/di.dart';
import 'package:reclite/app/router/app_shell.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';

class RecLiteApp extends StatelessWidget {
  const RecLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => getIt<SettingsCubit>(),
      child: BlocSelector<SettingsCubit, SettingsState, AppThemeMode>(
        selector: (s) => s.themeMode,
        builder: (context, mode) => MaterialApp(
          title: 'RecLite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (mode) {
            AppThemeMode.system => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
          },
          home: const AppShell(),
        ),
      ),
    );
  }
}
