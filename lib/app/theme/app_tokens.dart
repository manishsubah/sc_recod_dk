import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
}

abstract final class AppSize {
  static const double hairline = 1;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double iconXxl = 40;
  static const double iconDisplay = 48;

  static const double logo = 40;

  static const double recordDot = 12;
  static const double meterHeight = 6;
  static const double meterWidth = 140;
  static const double inlineProgress = 18;
  static const double progressStroke = 2;

  static const double buttonHeight = 52;
  static const double buttonMinWidth = 220;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class AppLayout {
  static const double contentMaxWidth = 760;
  static const double labelColumnWidth = 150;
}

abstract final class AppColors {
  static const Color brand = Color(0xFF1F5EFF);
  static const Color recording = Color(0xFFE5383B);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFF9800);
}
