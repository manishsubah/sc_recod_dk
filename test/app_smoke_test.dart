import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/app.dart';
import 'package:reclite/app/di.dart';
import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

import 'fixtures.dart';

class _FakeEngineRepository implements EngineRepository {
  @override
  Future<EngineInfo> getEngineInfo() async => testEngineInfo;

  @override
  Future<StorageInfo> getStorageInfo(String folder) async =>
      StorageInfo(path: folder, freeBytes: 48e9 ~/ 1, totalBytes: 500e9 ~/ 1);
}

void main() {
  late FakeRecorderRepository recorder;

  setUp(() {
    recorder = FakeRecorderRepository();
    getIt
      ..registerFactory<ReadinessCubit>(
        () => ReadinessCubit(_FakeEngineRepository(), outputFolder: '/rec'),
      )
      ..registerFactory<SourcesCubit>(() => SourcesCubit(recorder))
      ..registerFactory<AudioCubit>(() => AudioCubit(recorder))
      ..registerFactory<AudioLevelsCubit>(() => AudioLevelsCubit(recorder))
      ..registerFactory<RecordingBloc>(() => RecordingBloc(recorder))
      ..registerFactory<RecoveryCubit>(
        () => RecoveryCubit(recorder, outputFolder: '/rec'),
      );
  });

  tearDown(() async {
    await getIt.reset();
    await recorder.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shows readiness and navigates between sections', (tester) async {
    await pumpApp(tester);

    expect(find.text('Ready to Record'), findsOneWidget);
    expect(find.text('macOS 15.1.0'), findsOneWidget);
    expect(find.text('H.264 · HEVC'), findsOneWidget);
    expect(find.text('48.0 GB · about 40 h'), findsOneWidget);
    expect(
      find.text('Built-in Retina Display (3024 × 1964) · Main'),
      findsOneWidget,
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No recordings yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings are on the way'), findsOneWidget);
  });

  testWidgets('start → live timer → stop → saved', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    expect(recorder.startCalls.single.displayId, 1);
    expect(recorder.startCalls.single.outputFolder, '/rec');
    expect(find.text('REC'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    recorder.emitStatus(testStatus(65));
    await tester.pumpAndSettle();
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Part 1 · 65.0 MB'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Recording saved'), findsOneWidget);
    expect(find.text('RecLite_2026-11-19_10-00-00_Part01.mp4'), findsOneWidget);

    await tester.tap(find.text('New recording'));
    await tester.pumpAndSettle();
    expect(find.text('Start Recording'), findsOneWidget);
  });

  testWidgets('asks for screen permission when missing', (tester) async {
    recorder.permission = false;
    await pumpApp(tester);

    expect(find.text('Allow screen recording'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start Recording'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('records a dragged area', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Area'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    expect(recorder.startCalls.single.area, testArea);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recording'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsNothing);
  });

  testWidgets('fits the minimum window size with an area selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Area'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio toggles reach the recording and meters move', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('System sound'), findsOneWidget);

    await tester.tap(find.byType(Switch).last); // microphone
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    final config = recorder.startCalls.single;
    expect(config.captureSystemAudio, isTrue);
    expect(config.captureMicrophone, isTrue);

    recorder.emitLevels(const AudioLevels(system: 0.5, microphone: 0.95));
    await tester.pumpAndSettle();
    final meters = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((m) => m.value)
        .toList();
    expect(meters, containsAll(<double>[0.5, 0.95]));

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.every((s) => s.onChanged == null), isTrue);
  });

  testWidgets('blocked microphone stays off and offers Settings', (
    tester,
  ) async {
    recorder.microphonePermission = false;
    await pumpApp(tester);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
    expect(find.text('Microphone access is off.'), findsOneWidget);
  });

  testWidgets('pause, resume and a multi-part result', (tester) async {
    recorder.stopResult = testMultiPartResult;
    await pumpApp(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 1);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    recorder.emitStatus(testStatus(42, phase: RecordingPhase.paused));
    await tester.pumpAndSettle();
    expect(find.text('00:42'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(recorder.resumeCalls, 1);
    expect(find.text('REC'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('20:00 · 900 MB · 2 parts'), findsOneWidget);
    expect(find.text('RecLite_2026-11-19_10-00-00'), findsOneWidget);
  });

  testWidgets('shows the recovery banner after an interrupted recording', (
    tester,
  ) async {
    recorder.recoverable = const [testRecovered];
    await pumpApp(tester);

    expect(find.text('RecLite recovered a recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('RecLite recovered a recording'), findsNothing);
  });

  testWidgets('recording bar fits the minimum window size', (tester) async {
    tester.view.physicalSize = const Size(760, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Recording'));
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pause'));
    expect(find.text('Pause'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
