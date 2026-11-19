import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('bytes', () => expect(formatBytes(512), '512 B'));
    test('megabytes', () => expect(formatBytes(1500000), '1.5 MB'));
    test('gigabytes', () => expect(formatBytes(120400000000), '120 GB'));
    test('small GB', () => expect(formatBytes(1500000000), '1.5 GB'));
  });

  group('formatRecordingTimeLeft', () {
    const perHour = 1200 * 1000 * 1000;
    test(
      'hours',
      () => expect(
        formatRecordingTimeLeft(48e9 ~/ 1, estimatedBytesPerHour: perHour),
        'about 40 h',
      ),
    );
    test(
      'minutes',
      () => expect(
        formatRecordingTimeLeft(600e6 ~/ 1, estimatedBytesPerHour: perHour),
        'about 30 min',
      ),
    );
    test(
      'none',
      () => expect(
        formatRecordingTimeLeft(0, estimatedBytesPerHour: perHour),
        'no space',
      ),
    );
  });

  group('formatElapsed', () {
    test(
      'seconds',
      () => expect(formatElapsed(const Duration(seconds: 7)), '00:07'),
    );
    test(
      'minutes',
      () => expect(
        formatElapsed(const Duration(minutes: 14, seconds: 5)),
        '14:05',
      ),
    );
    test(
      'hours',
      () => expect(
        formatElapsed(const Duration(hours: 2, minutes: 3, seconds: 9)),
        '2:03:09',
      ),
    );
  });

  group('formatSegmentLength', () {
    test(
      'minutes',
      () => expect(
        formatSegmentLength(const Duration(minutes: 15)),
        '15 minutes',
      ),
    );
    test(
      'seconds',
      () => expect(
        formatSegmentLength(const Duration(seconds: 20)),
        '20 seconds',
      ),
    );
  });
}
