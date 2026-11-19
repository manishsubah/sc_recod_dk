import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di.dart';

// Window chrome: macos/Runner/MainFlutterWindow.swift, windows/runner/main.cpp.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const RecLiteApp());
}
