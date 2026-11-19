/// Human-readable byte size, e.g. `1.5 GB`. Uses 1000-based units like
/// Finder and Explorer's "free space" display.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// Rough recording time that fits in [freeBytes], e.g. `about 40 h`.
String formatRecordingTimeLeft(
  int freeBytes, {
  required int estimatedBytesPerHour,
}) {
  final hours = freeBytes / estimatedBytesPerHour;
  if (hours >= 1) return 'about ${hours.floor()} h';
  final minutes = (hours * 60).floor();
  return minutes <= 0 ? 'no space' : 'about $minutes min';
}
