import 'dart:io';

import 'package:flutter/foundation.dart';

abstract final class RecordingDefaults {
  static const Duration standardSegmentDuration = Duration(minutes: 15);

  /// Debug builds accept `RECLITE_SEGMENT_SECONDS` so part switching can be tested
  /// without waiting; it wins over the Settings choice. Null in release builds.
  static Duration? get debugSegmentOverride {
    if (!kDebugMode) return null;
    final seconds = int.tryParse(
      Platform.environment['RECLITE_SEGMENT_SECONDS'] ?? '',
    );
    return seconds != null && seconds >= 5 ? Duration(seconds: seconds) : null;
  }

  static const List<int> segmentMinuteChoices = [5, 10, 15, 30, 60];
  static const List<int> maxHeightChoices = [360, 480, 720, 1080, 1440];
  static const List<int> framesPerSecondChoices = [30, 60];

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
