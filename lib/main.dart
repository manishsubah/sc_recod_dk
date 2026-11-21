import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di.dart';

// Window chrome: macos/Runner/MainFlutterWindow.swift, windows/runner/main.cpp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies(await SharedPreferences.getInstance());
  runApp(const RecLiteApp());
}
