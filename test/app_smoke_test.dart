import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/app.dart';
import 'package:reclite/app/di.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
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
      ..registerFactory<RecordingBloc>(() => RecordingBloc(recorder));
  });

  tearDown(() async {
    await getIt.reset();
    await recorder.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
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
}
