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

String formatRecordingTimeLeft(
  int freeBytes, {
  required int estimatedBytesPerHour,
}) {
  final hours = freeBytes / estimatedBytesPerHour;
  if (hours >= 1) return 'about ${hours.floor()} h';
  final minutes = (hours * 60).floor();
  return minutes <= 0 ? 'no space' : 'about $minutes min';
}

/// `05:07` under an hour, `1:05:07` after.
String formatElapsed(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = d.inHours;
  final minutes = two(d.inMinutes.remainder(60));
  final seconds = two(d.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// `15 minutes`, or `20 seconds` for short (debug) parts.
String formatSegmentLength(Duration d) =>
    d.inMinutes >= 1 && d.inSeconds % 60 == 0
    ? '${d.inMinutes} minutes'
    : '${d.inSeconds} seconds';
