import 'package:flutter/material.dart';

/// RecLite design tokens on top of Material 3.
///
/// Kept deliberately simple: no custom fonts, no heavy effects, minimal
/// animation — the UI should cost as little as possible while recording.
abstract final class AppTheme {
  /// Brand blue from the RecLite mockup.
  static const Color brand = Color(0xFF1F5EFF);

  /// Recording red (REC dot, stop button).
  static const Color recording = Color(0xFFE5383B);

  static const double radius = 14;

  // NOTE: scaffold backgrounds (#FAF8FF light, #121318 dark) are mirrored in
  // macos/Runner/MainFlutterWindow.swift to avoid a black flash at launch.
  // Update it if the seed colour changes. (Windows needs nothing: its runner
  // only shows the window after Flutter's first frame.)

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        labelType: NavigationRailLabelType.all,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
