import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';

/// Which desktop design language the shell follows.
enum UiLook {
  /// Windows 11 (Fluent): 14 px body, 4 px controls, 8 px layers.
  windows,

  /// macOS: 13 px body, 6 px controls, 10 px panels.
  mac;

  static UiLook get current => defaultTargetPlatform == TargetPlatform.macOS
      ? UiLook.mac
      : UiLook.windows;
}

/// Colours and per-OS metrics for RecLite's own widgets.
@immutable
class RecLiteTokens extends ThemeExtension<RecLiteTokens> {
  const RecLiteTokens({
    required this.look,
    required this.brightness,
    required this.ground,
    required this.pane,
    required this.paneRaised,
    required this.seam,
    required this.seamStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.tally,
    required this.tallyInk,
    required this.tallyTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.hover,
    required this.pressed,
  });

  factory RecLiteTokens.of(UiLook look, Brightness brightness) =>
      brightness == Brightness.light
      ? RecLiteTokens(
          look: look,
          brightness: brightness,
          ground: AppPalette.lightGround,
          pane: AppPalette.lightPane,
          paneRaised: AppPalette.lightPaneRaised,
          seam: AppPalette.lightSeam,
          seamStrong: AppPalette.lightSeamStrong,
          ink: AppPalette.lightInk,
          inkMuted: AppPalette.lightInkMuted,
          inkFaint: AppPalette.lightInkFaint,
          accent: AppPalette.lightAccent,
          onAccent: AppPalette.lightOnAccent,
          accentTint: AppPalette.lightAccentTint,
          tally: AppPalette.lightTally,
          tallyInk: AppPalette.lightTallyInk,
          tallyTint: AppPalette.lightTallyTint,
          success: AppPalette.lightSuccess,
          warning: AppPalette.lightWarning,
          danger: AppPalette.lightDanger,
          hover: AppPalette.lightHover,
          pressed: AppPalette.lightPressed,
        )
      : RecLiteTokens(
          look: look,
          brightness: brightness,
          ground: AppPalette.darkGround,
          pane: AppPalette.darkPane,
          paneRaised: AppPalette.darkPaneRaised,
          seam: AppPalette.darkSeam,
          seamStrong: AppPalette.darkSeamStrong,
          ink: AppPalette.darkInk,
          inkMuted: AppPalette.darkInkMuted,
          inkFaint: AppPalette.darkInkFaint,
          accent: AppPalette.darkAccent,
          onAccent: AppPalette.darkOnAccent,
          accentTint: AppPalette.darkAccentTint,
          tally: AppPalette.darkTally,
          tallyInk: AppPalette.darkTallyInk,
          tallyTint: AppPalette.darkTallyTint,
          success: AppPalette.darkSuccess,
          warning: AppPalette.darkWarning,
          danger: AppPalette.darkDanger,
          hover: AppPalette.darkHover,
          pressed: AppPalette.darkPressed,
        );

  final UiLook look;
  final Brightness brightness;

  /// Window background: sidebar and the area around panes.
  final Color ground;

  /// Content layer and grouped panes.
  final Color pane;
  final Color paneRaised;

  /// 1 px dividers between panes and rows.
  final Color seam;
  final Color seamStrong;
  final Color ink;
  final Color inkMuted;

  /// Decorative or disabled only; never for text that must be read.
  final Color inkFaint;

  /// Selection, focus, switches, progress.
  final Color accent;
  final Color onAccent;
  final Color accentTint;

  /// Recording only.
  final Color tally;

  /// Tally colour for text and small marks on the pane.
  final Color tallyInk;
  final Color tallyTint;
  final Color success;
  final Color warning;
  final Color danger;
  final Color hover;
  final Color pressed;

  bool get isMac => look == UiLook.mac;

  double get controlRadius => isMac ? AppRadius.md : AppRadius.sm;
  double get paneRadius => isMac ? AppRadius.xl : AppRadius.lg;
  double get controlHeight => isMac ? 28 : 32;
  double get navItemHeight => isMac ? 30 : 36;
  double get rowMinHeight => isMac ? 44 : 52;
  double get bodySize => isMac ? 13 : 14;

  @override
  RecLiteTokens copyWith() => this;

  @override
  RecLiteTokens lerp(RecLiteTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension RecLiteTokensContext on BuildContext {
  RecLiteTokens get tokens => Theme.of(this).extension<RecLiteTokens>()!;
}

abstract final class AppTheme {
  static ThemeData light({UiLook? look}) =>
      _build(look ?? UiLook.current, Brightness.light);

  static ThemeData dark({UiLook? look}) =>
      _build(look ?? UiLook.current, Brightness.dark);

  static ThemeData _build(UiLook look, Brightness brightness) {
    final t = RecLiteTokens.of(look, brightness);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentTint,
      onPrimaryContainer: t.ink,
      secondary: t.inkMuted,
      onSecondary: t.pane,
      secondaryContainer: t.paneRaised,
      onSecondaryContainer: t.ink,
      tertiary: t.tally,
      onTertiary: AppPalette.lightOnAccent,
      error: t.danger,
      onError: t.pane,
      errorContainer: t.tallyTint,
      onErrorContainer: t.ink,
      surface: t.pane,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      surfaceContainerLowest: t.paneRaised,
      surfaceContainerLow: t.pane,
      surfaceContainer: t.ground,
      surfaceContainerHigh: t.paneRaised,
      surfaceContainerHighest: t.seam,
      outline: t.seamStrong,
      outlineVariant: t.seam,
      shadow: const Color(0xFF000000),
      inverseSurface: t.ink,
      onInverseSurface: t.pane,
      inversePrimary: t.accent,
      surfaceTint: Colors.transparent,
    );

    final text = _textTheme(look, t);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.controlRadius),
    );
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: look == UiLook.mac ? AppSpacing.sm : AppSpacing.md,
    );
    final buttonSize = Size(0, t.controlHeight);
    final label = text.labelLarge?.copyWith(
      fontFamily: _fontFamily(look),
      fontFamilyFallback: _fontFallback(look),
    );
    WidgetStateProperty<Color?> overlay(Color base) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed)
              ? base.withValues(alpha: 0.16)
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
              ? base.withValues(alpha: 0.08)
              : null,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [t],
      textTheme: text,
      fontFamily: _fontFamily(look),
      fontFamilyFallback: _fontFallback(look),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      scaffoldBackgroundColor: t.ground,
      canvasColor: t.pane,
      splashFactory: NoSplash.splashFactory,
      hoverColor: t.hover,
      highlightColor: t.pressed,
      focusColor: t.accentTint,
      dividerTheme: DividerThemeData(
        color: t.seam,
        space: AppSize.hairline,
        thickness: AppSize.hairline,
      ),
      iconTheme: IconThemeData(color: t.inkMuted, size: AppSize.iconLg),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accentTint,
        selectionHandleColor: t.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AppRadius.sm),
        thumbColor: WidgetStatePropertyAll(t.seamStrong),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          minimumSize: WidgetStatePropertyAll(buttonSize),
          padding: WidgetStatePropertyAll(buttonPadding),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(label),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? t.seam : t.accent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? t.inkMuted : t.onAccent,
          ),
          overlayColor: overlay(t.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          minimumSize: WidgetStatePropertyAll(buttonSize),
          padding: WidgetStatePropertyAll(buttonPadding),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(label),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? null : t.paneRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? t.inkFaint : t.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? t.seam : t.seamStrong,
            ),
          ),
          overlayColor: overlay(t.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          minimumSize: WidgetStatePropertyAll(buttonSize),
          padding: WidgetStatePropertyAll(buttonPadding),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(label),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? t.inkFaint : t.accent,
          ),
          overlayColor: overlay(t.accent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(AppSize.iconButton),
          ),
          fixedSize: const WidgetStatePropertyAll(
            Size.square(AppSize.iconButton),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          iconSize: const WidgetStatePropertyAll(AppSize.iconLg),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? t.inkFaint : t.inkMuted,
          ),
          overlayColor: overlay(t.ink),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(label),
          iconSize: const WidgetStatePropertyAll(AppSize.iconMd),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? t.seam : t.seamStrong,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? (s.contains(WidgetState.disabled)
                      ? t.seam
                      : t.isMac
                      ? t.seamStrong
                      : t.accentTint)
                : (t.isMac ? t.pane : t.paneRaised),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? t.inkFaint
                : s.contains(WidgetState.selected)
                ? t.ink
                : t.inkMuted,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? t.inkFaint
                : s.contains(WidgetState.selected)
                ? t.accent
                : t.inkMuted,
          ),
          overlayColor: overlay(t.ink),
        ),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        trackOutlineWidth: const WidgetStatePropertyAll(1),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) || t.isMac
              ? Colors.transparent
              : s.contains(WidgetState.disabled)
              ? t.seam
              : t.inkMuted,
        ),
        // On but locked (while recording) keeps a dimmed accent track so it
        // never reads as off.
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (s.contains(WidgetState.disabled)
                    ? t.accent.withValues(alpha: 0.45)
                    : t.accent)
              : t.isMac
              ? (s.contains(WidgetState.disabled) ? t.seam : t.seamStrong)
              : t.paneRaised,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) || t.isMac
              ? Colors.white
              : s.contains(WidgetState.disabled)
              ? t.seamStrong
              : t.inkMuted,
        ),
        thumbIcon: t.isMac ? const WidgetStatePropertyAll(Icon(null)) : null,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.seam,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: text.bodySmall?.copyWith(color: t.pane),
        decoration: BoxDecoration(
          color: t.ink.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(t.controlRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.paneRaised,
        elevation: 8,
        shadowColor: const Color(0x40000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.paneRadius),
          side: BorderSide(color: t.seam),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.inkMuted),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.paneRaised,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.paneRadius),
          side: BorderSide(color: t.seam),
        ),
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.pane),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.paneRadius),
        ),
        width: 420,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        iconColor: t.inkMuted,
        textColor: t.ink,
        shape: controlShape,
      ),
    );
  }

  /// Segoe UI Variable on Windows 11 (Segoe UI on 10); San Francisco on Mac.
  static String _fontFamily(UiLook look) =>
      look == UiLook.windows ? 'Segoe UI Variable Text' : '.AppleSystemUIFont';

  static List<String>? _fontFallback(UiLook look) =>
      look == UiLook.windows ? const ['Segoe UI'] : null;

  /// Fluent's ramp on Windows (Caption 12, Body 14, Subtitle 20, Title 28),
  /// macOS's on Mac (11 / 13 / 15 / 22). Tight 1.15–1.25 steps for a tool.
  static TextTheme _textTheme(UiLook look, RecLiteTokens t) {
    final mac = look == UiLook.mac;
    final base =
        Typography.material2021(
          platform: mac ? TargetPlatform.macOS : TargetPlatform.windows,
        ).englishLike.merge(
          t.brightness == Brightness.light
              ? Typography.material2021().black
              : Typography.material2021().white,
        );
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? t.ink,
      letterSpacing: 0,
    );
    final body = mac ? 13.0 : 14.0;
    return base.copyWith(
      displaySmall: s(mac ? 34 : 40, FontWeight.w300, height: 1.1).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -0.5,
      ),
      headlineSmall: s(
        mac ? 22 : 28,
        mac ? FontWeight.w700 : FontWeight.w600,
        height: 1.2,
      ),
      titleLarge: s(mac ? 15 : 20, FontWeight.w600, height: 1.3),
      titleMedium: s(body, FontWeight.w600, height: 1.35),
      titleSmall: s(body, FontWeight.w600, height: 1.35),
      bodyLarge: s(body, FontWeight.w400, height: 1.45),
      bodyMedium: s(body, FontWeight.w400, height: 1.45),
      bodySmall: s(
        mac ? 11 : 12,
        FontWeight.w400,
        height: 1.35,
        color: t.inkMuted,
      ),
      labelLarge: s(body, mac ? FontWeight.w500 : FontWeight.w600, height: 1.2),
      labelMedium: s(mac ? 11 : 12, FontWeight.w600, height: 1.2),
      labelSmall: s(
        mac ? 10 : 11,
        FontWeight.w600,
        height: 1.2,
        color: t.inkMuted,
      ).copyWith(letterSpacing: 1.1),
    );
  }
}
