// Records the real screen for a few seconds and checks the MP4 on disk.
// Needs Screen Recording permission for RecLite; skipped otherwise.
//
//   flutter test integration_test/recording_test.dart -d macos
import 'dart:convert';
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
    expect(file.lengthSync(), greaterThan(10 * 1024));

    // The save folder holds just the video: no subfolder, manifest or .part.
    expect(file.parent.path, out.path);
    expect(
      file.uri.pathSegments.last,
      matches(RegExp(r'^RecLite_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.mp4$')),
    );
    expect(out.listSync().map((e) => e.path), [file.path]);

    // The manifest lives in the app's data folder and points back here.
    final manifest = File(
      '${await engine.getSessionsDirectory()}${Platform.pathSeparator}'
      '${file.uri.pathSegments.last.replaceAll('.mp4', '.json')}',
    );
    expect(manifest.existsSync(), isTrue);
    final json =
        jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
    expect(json['status'], 'completed');
    expect(json['directory'], out.path);
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

    // Leave nothing behind in the user's History.
    manifest.deleteSync();
    out.deleteSync(recursive: true);
  });

  testWidgets('a long recording is saved as parts sharing one name', (_) async {
    if (!(await engine.getCapabilities()).supportsRecording ||
        !await engine.hasScreenCapturePermission()) {
      markTestSkipped('Recording is not available here.');
      return;
    }
    final display = (await engine.listDisplays()).firstWhere((d) => d.isMain);
    final out = Directory.systemTemp.createTempSync('reclite_it_parts_');

    await engine.startRecording(
      EngineRecordingRequest(
        displayId: display.id,
        outputDirectory: out.path,
        framesPerSecond: 30,
        maxHeight: 360,
        captureSystemAudio: false,
        captureMicrophone: false,
        showCursor: true,
        segmentSeconds: 5,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 7));
    final result = await engine.stopRecording();

    final names = [
      for (final f in result.files) f.split(r'\').last.split('/').last,
    ];
    expect(names, hasLength(2));
    final base = names.first.replaceAll('_Part01.mp4', '');
    expect(names, ['${base}_Part01.mp4', '${base}_Part02.mp4']);
    expect(
      out.listSync().map((e) => e.path).toList()..sort(),
      [...result.files]..sort(),
      reason: 'the folder holds only the videos',
    );

    // ignore: avoid_print
    print('PARTS: $names ${result.durationMs} ms');

    File(
      '${await engine.getSessionsDirectory()}${Platform.pathSeparator}$base.json',
    ).deleteSync();
    out.deleteSync(recursive: true);
  });

  testWidgets('stop without a recording is rejected', (_) async {
    await expectLater(engine.stopRecording(), throwsA(isA<Exception>()));
  });
}
