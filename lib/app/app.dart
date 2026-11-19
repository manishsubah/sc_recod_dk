import 'package:flutter/material.dart';

import 'router/app_shell.dart';
import 'theme/app_theme.dart';

class RecLiteApp extends StatelessWidget {
  const RecLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecLite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
