import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/core/constants/app_info.dart';

void main() {
  test('About shows the version from pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\+(\d+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(AppInfo.version, match.group(1));
    expect(AppInfo.build, int.parse(match.group(2)!));
  });
}
