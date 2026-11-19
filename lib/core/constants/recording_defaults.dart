import 'dart:io';

/// Defaults from docs/PLAN.md §8.4 and §16.
abstract final class RecordingDefaults {
  static const Duration segmentDuration = Duration(minutes: 15);

  /// Typical 1080p30 H.264 screen recording (~300 MB per 15 min).
  /// Used only for the "estimated time left" hint; refined in Phase 4.
  static const int estimatedBytesPerHour = 1200 * 1000 * 1000;

  /// Refuse to start below this much free space.
  static const int minFreeBytesToStart = 1000 * 1000 * 1000;

  static const String appFolderName = 'RecLite';

  /// `~/Movies/RecLite` on macOS, `%USERPROFILE%\Videos\RecLite` on Windows.
  static String outputFolder() {
    final sep = Platform.pathSeparator;
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'] ?? r'C:\';
      return '$profile${sep}Videos$sep$appFolderName';
    }
    final home = Platform.environment['HOME'] ?? '/';
    return '$home${sep}Movies$sep$appFolderName';
  }
}
