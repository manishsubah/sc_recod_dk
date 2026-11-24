import 'package:flutter/material.dart';

/// Raw design values. Widgets read colours and per-OS metrics through
/// `context.tokens` (see reclite_theme.dart); only spacing, sizes and motion
/// are read from here directly.
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

  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 18;
  static const double iconLg = 20;
  static const double iconXl = 24;
  static const double iconXxl = 32;

  static const double logo = 28;
  static const double aboutIcon = 64;

  static const double recordDot = 10;
  static const double tallyDot = 12;
  static const double meterWidth = 120;
  static const double meterHeight = 6;
  static const double meterSegments = 24;
  static const double partStripHeight = 6;
  static const double partTick = 4;
  static const double inlineProgress = 16;
  static const double progressStroke = 2;

  static const double compactButtonWidth = 96;
  static const double iconButton = 32;
  static const double keyCap = 24;
}

abstract final class AppRadius {
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 10;
}

abstract final class AppLayout {
  static const double contentMaxWidth = 880;
  static const double readingMaxWidth = 640;
  static const double labelColumnWidth = 128;
  static const double navWidth = 220;
  static const double navCompactWidth = 60;

  /// Below this window width the sidebar shows icons only.
  static const double navCompactBreakpoint = 940;

  /// Below this content width History hides its size and parts columns.
  static const double historyColumnsBreakpoint = 700;
  static const double historyDurationColumn = 72;
  static const double historySizeColumn = 76;
  static const double historyPartsColumn = 96;
  static const double displayPickerWidth = 300;
  static const double windowPickerWidth = 480;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Curve ease = Curves.easeOutCubic;
}

/// Film-edge palette: neutral native grounds (Windows 11 / macOS greys), one amber accent for selection
/// and progress, tally red reserved for recording.
abstract final class AppPalette {
  // Light
  static const Color lightGround = Color(0xFFF3F3F3);
  static const Color lightPane = Color(0xFFF9F9F9);
  static const Color lightPaneRaised = Color(0xFFFFFFFF);
  static const Color lightSeam = Color(0xFFE5E5E5);
  static const Color lightSeamStrong = Color(0xFFCCCCCC);
  static const Color lightInk = Color(0xFF1B1B1B);
  static const Color lightInkMuted = Color(0xFF5C5C5C);
  static const Color lightInkFaint = Color(0xFF8A8A8A);
  static const Color lightAccent = Color(0xFFA85400);
  static const Color lightOnAccent = Color(0xFFFFFFFF);
  static const Color lightAccentTint = Color(0x1FA85400);
  static const Color lightTally = Color(0xFFD42F3F);
  static const Color lightTallyInk = Color(0xFFC2283A);
  static const Color lightTallyTint = Color(0x14D42F3F);
  static const Color lightSuccess = Color(0xFF2E7D32);
  static const Color lightWarning = Color(0xFF9D5D00);
  static const Color lightDanger = Color(0xFFC42B1C);
  static const Color lightHover = Color(0x0D1B1B1B);
  static const Color lightPressed = Color(0x171B1B1B);

  // Dark
  static const Color darkGround = Color(0xFF202020);
  static const Color darkPane = Color(0xFF272727);
  static const Color darkPaneRaised = Color(0xFF2D2D2D);
  static const Color darkSeam = Color(0xFF3A3A3A);
  static const Color darkSeamStrong = Color(0xFF4D4D4D);
  static const Color darkInk = Color(0xFFF3F3F3);
  static const Color darkInkMuted = Color(0xFFB0B0B0);
  static const Color darkInkFaint = Color(0xFF808080);
  static const Color darkAccent = Color(0xFFF0A24B);
  static const Color darkOnAccent = Color(0xFF202020);
  static const Color darkAccentTint = Color(0x29F0A24B);
  static const Color darkTally = Color(0xFFD93A47);
  static const Color darkTallyInk = Color(0xFFFF6B74);
  static const Color darkTallyTint = Color(0x1FFF6B74);
  static const Color darkSuccess = Color(0xFF6CCB5F);
  static const Color darkWarning = Color(0xFFF2C94C);
  static const Color darkDanger = Color(0xFFFF99A4);
  static const Color darkHover = Color(0x0FF3F3F3);
  static const Color darkPressed = Color(0x1AF3F3F3);

  /// Keep macos/Runner/MainFlutterWindow.swift in sync to avoid a launch flash.
  static const Color launchLight = lightGround;
  static const Color launchDark = darkGround;
}
