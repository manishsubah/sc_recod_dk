// Runs against the REAL native engine inside the built app.
//
//   flutter test integration_test -d macos     (or -d windows)
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reclite_engine/reclite_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = RecliteEngine();

  testWidgets('getCapabilities returns real data from native code', (_) async {
    final caps = await engine.getCapabilities();

    expect(
      caps.platform,
      Platform.isMacOS ? HostPlatform.macos : HostPlatform.windows,
    );
    expect(caps.osVersion, isNotEmpty);
    expect(caps.meetsMinimumOs, isTrue);
    expect(caps.supportsSystemAudio, isTrue);
    expect(caps.engineVersion, '0.1.0');

    // ignore: avoid_print
    print(
      'ENGINE: ${caps.platform.name} ${caps.osVersion} '
      '(min ${caps.minimumOsVersion}) '
      'hwH264=${caps.hasHardwareH264Encoder} '
      'hwHEVC=${caps.hasHardwareHevcEncoder} '
      'scMic=${caps.supportsMicrophoneViaScreenCapture}',
    );
  });

  testWidgets('getDiskSpace reports the home volume', (_) async {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME']!;
    final space = await engine.getDiskSpace(home);

    expect(space.totalBytes, greaterThan(0));
    expect(space.freeBytes, inInclusiveRange(1, space.totalBytes));
  });

  testWidgets('getDiskSpace rejects a missing path', (_) async {
    await expectLater(
      engine.getDiskSpace('/definitely/not/here/reclite'),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'invalid_path'),
      ),
    );
  });
}
