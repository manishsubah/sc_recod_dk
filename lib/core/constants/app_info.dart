/// Product details shown in Help → About. `version` and `build` must match
/// pubspec.yaml (a test checks this).
abstract final class AppInfo {
  static const String name = 'RecLite';
  static const String version = '2.0.1';
  static const int build = 2;

  static const String copyrightHolder = 'RecLite';
  static const int copyrightYear = 2026;

  static String get copyright =>
      '© $copyrightYear $copyrightHolder. All rights reserved.';

  /// Fill in to show "Email support" in Help; empty hides it.
  static const String supportEmail = '';

  /// Fill in (https://…) to show "Visit website" in Help; empty hides it.
  static const String website = '';

  static const String iconAsset = 'assets/reclite_icon.png';
}
