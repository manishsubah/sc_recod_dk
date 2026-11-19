import 'dart:io';

import 'package:flutter/foundation.dart';

abstract final class RecordingDefaults {
  static const Duration standardSegmentDuration = Duration(minutes: 15);

  /// Debug builds accept `RECLITE_SEGMENT_SECONDS` so part switching can be tested
  /// without waiting 15 minutes. Release builds always use 15 minutes.
  static Duration get segmentDuration {
    if (kDebugMode) {
      final seconds = int.tryParse(
        Platform.environment['RECLITE_SEGMENT_SECONDS'] ?? '',
      );
      if (seconds != null && seconds >= 5) return Duration(seconds: seconds);
    }
    return standardSegmentDuration;
  }

  static const int framesPerSecond = 30;
  static const int maxOutputHeight = 1440;

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
