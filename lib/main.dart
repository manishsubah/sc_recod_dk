import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di.dart';

// Window title, size and minimum size are set natively:
// macos/Runner/MainFlutterWindow.swift and windows/runner/main.cpp.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const RecLiteApp());
}
