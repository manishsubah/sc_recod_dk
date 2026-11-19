import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';

import '../../fixtures.dart';

class MockRecorderRepository extends Mock implements RecorderRepository {}

void main() {
  late MockRecorderRepository repo;
  late StreamController<RecordingStatus> status;
  late StreamController<RecordingInterruption> interruptions;

  setUpAll(() => registerFallbackValue(testConfig));

  setUp(() {
    repo = MockRecorderRepository();
    status = StreamController<RecordingStatus>.broadcast();
    interruptions = StreamController<RecordingInterruption>.broadcast();
    when(() => repo.status).thenAnswer((_) => status.stream);
    when(() => repo.interruptions).thenAnswer((_) => interruptions.stream);
    when(() => repo.start(any())).thenAnswer((_) async {});
    when(() => repo.stop()).thenAnswer((_) async => testResult);
    when(() => repo.pause()).thenAnswer((_) async {});
    when(() => repo.resume()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await status.close();
    await interruptions.close();
  });

  RecordingBloc build() => RecordingBloc(repo);

  blocTest<RecordingBloc, RecordingState>(
    'start: Starting then Active',
    build: build,
    act: (b) => b.add(const RecordingStartRequested(testConfig)),
    expect: () => [
      const RecordingStarting(),
      const RecordingActive(RecordingStatus.initial),
    ],
    verify: (_) => verify(() => repo.start(testConfig)).called(1),
  );

  blocTest<RecordingBloc, RecordingState>(
    'start failure shows a user-safe message',
    setUp: () => when(() => repo.start(any()))
        .thenThrow(const PermissionFailure('RecLite needs screen permission.')),
    build: build,
    act: (b) => b.add(const RecordingStartRequested(testConfig)),
    expect: () => [
      const RecordingStarting(),
      const RecordingFailed('RecLite needs screen permission.'),
    ],
  );

  blocTest<RecordingBloc, RecordingState>(
    'engine ticks update the active status',
    build: build,
    seed: () => const RecordingActive(RecordingStatus.initial),
    act: (_) => status.add(testStatus(3)),
    expect: () => [RecordingActive(testStatus(3))],
  );

  blocTest<RecordingBloc, RecordingState>(
    'ticks are ignored when not recording',
    build: build,
    act: (_) => status.add(testStatus(3)),
    expect: () => <RecordingState>[],
  );

  blocTest<RecordingBloc, RecordingState>(
    'stop: Stopping then Finished with the result',
    build: build,
    seed: () => RecordingActive(testStatus(65)),
    act: (b) => b.add(const RecordingStopRequested()),
    expect: () => [
      RecordingStopping(testStatus(65)),
      const RecordingFinished(testResult),
    ],
  );

  blocTest<RecordingBloc, RecordingState>(
    'stop is ignored when idle',
    build: build,
    act: (b) => b.add(const RecordingStopRequested()),
    expect: () => <RecordingState>[],
    verify: (_) => verifyNever(() => repo.stop()),
  );

  blocTest<RecordingBloc, RecordingState>(
    'a fatal interruption ends the session with its message',
    build: build,
    seed: () => RecordingActive(testStatus(10)),
    act: (_) => interruptions.add(
      const RecordingInterruption(
        message: 'Stopped from the menu bar.',
        isFatal: true,
      ),
    ),
    expect: () => [const RecordingFailed('Stopped from the menu bar.')],
  );

  blocTest<RecordingBloc, RecordingState>(
    'dismiss returns to idle',
    build: build,
    seed: () => const RecordingFinished(testResult),
    act: (b) => b.add(const RecordingDismissed()),
    expect: () => [const RecordingIdle()],
  );

  group('pause / resume', () {
    blocTest<RecordingBloc, RecordingState>(
      'pause flips to paused right away and tells the engine',
      build: build,
      seed: () => RecordingActive(testStatus(30)),
      act: (b) => b.add(const RecordingPauseRequested()),
      expect: () => [
        RecordingActive(testStatus(30, phase: RecordingPhase.paused)),
      ],
      verify: (_) => verify(() => repo.pause()).called(1),
    );

    blocTest<RecordingBloc, RecordingState>(
      'resume goes back to recording',
      build: build,
      seed: () => RecordingActive(testStatus(30, phase: RecordingPhase.paused)),
      act: (b) => b.add(const RecordingResumeRequested()),
      expect: () => [RecordingActive(testStatus(30))],
      verify: (_) => verify(() => repo.resume()).called(1),
    );

    blocTest<RecordingBloc, RecordingState>(
      'paused engine ticks keep the session active',
      build: build,
      seed: () => RecordingActive(testStatus(30)),
      act: (_) => status.add(testStatus(30, phase: RecordingPhase.paused)),
      expect: () => [
        RecordingActive(testStatus(30, phase: RecordingPhase.paused)),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'stop works while paused',
      build: build,
      seed: () => RecordingActive(testStatus(30, phase: RecordingPhase.paused)),
      act: (b) => b.add(const RecordingStopRequested()),
      expect: () => [
        RecordingStopping(testStatus(30, phase: RecordingPhase.paused)),
        const RecordingFinished(testResult),
      ],
    );
  });

  blocTest<RecordingBloc, RecordingState>(
    'a non-fatal warning is shown without ending the recording',
    build: build,
    seed: () => RecordingActive(testStatus(10)),
    act: (_) => interruptions.add(
      const RecordingInterruption(message: 'Low disk space.', isFatal: false),
    ),
    expect: () => [RecordingActive(testStatus(10), warning: 'Low disk space.')],
  );

  blocTest<RecordingBloc, RecordingState>(
    'the warning survives later ticks',
    build: build,
    seed: () => RecordingActive(testStatus(10), warning: 'Low disk space.'),
    act: (_) => status.add(testStatus(11)),
    expect: () => [RecordingActive(testStatus(11), warning: 'Low disk space.')],
  );
}
