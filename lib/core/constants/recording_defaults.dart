import 'dart:io';

abstract final class RecordingDefaults {
  static const Duration segmentDuration = Duration(minutes: 15);

  // Rough 1080p30 H.264 bitrate for the "time left" hint only.
  static const int estimatedBytesPerHour = 1200 * 1000 * 1000;

  static const int minFreeBytesToStart = 1000 * 1000 * 1000;

  static const String appFolderName = 'RecLite';

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
