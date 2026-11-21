// Records the real screen for a few seconds and checks the MP4 on disk.
// Needs Screen Recording permission for RecLite; skipped otherwise.
//
//   flutter test integration_test/recording_test.dart -d macos
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reclite_engine/reclite_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = RecliteEngine();

  testWidgets('records the main display to a playable MP4', (_) async {
    final caps = await engine.getCapabilities();
    if (!caps.supportsRecording) {
      markTestSkipped('Recording is not implemented on ${caps.platform.name}.');
      return;
    }
    if (!await engine.hasScreenCapturePermission()) {
      await engine.requestScreenCapturePermission();
      markTestSkipped(
        'RecLite has no Screen Recording permission. Grant it in System '
        'Settings → Privacy & Security, then re-run.',
      );
      return;
    }

    final displays = await engine.listDisplays();
    expect(displays, isNotEmpty);
    final display = displays.firstWhere((d) => d.isMain);

    final out = Directory.systemTemp.createTempSync('reclite_it_');
    final statuses = <EngineRecordingStatus>[];
    final sub = engine.status.listen(statuses.add);

    final session = await engine.startRecording(
      EngineRecordingRequest(
        displayId: display.id,
        outputDirectory: out.path,
        framesPerSecond: 30,
        maxHeight: 1080,
        captureSystemAudio: true,
        captureMicrophone: false,
        showCursor: true,
        segmentSeconds: 900,
      ),
    );
    expect(session.height, lessThanOrEqualTo(1080));
    expect(session.width.isEven && session.height.isEven, isTrue);

    await Future<void>.delayed(const Duration(seconds: 3));
    final result = await engine.stopRecording();
    await sub.cancel();

    final file = File(result.files.single);
    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('_Part01.mp4'));
    expect(File('${file.path}.part').existsSync(), isFalse);
    expect(file.lengthSync(), greaterThan(10 * 1024));
    expect(result.durationMs, inInclusiveRange(2500, 5000));
    expect(
      statuses.map((s) => s.phase),
      containsAllInOrder([
        EngineRecordingPhase.starting,
        EngineRecordingPhase.recording,
        EngineRecordingPhase.stopping,
        EngineRecordingPhase.idle,
      ]),
    );

    // ignore: avoid_print
    print(
      'RECORDED: ${file.path} ${session.width}x${session.height} '
      '${result.durationMs} ms ${file.lengthSync()} bytes',
    );
  });

  testWidgets('stop without a recording is rejected', (_) async {
    await expectLater(engine.stopRecording(), throwsA(isA<Exception>()));
  });
}
