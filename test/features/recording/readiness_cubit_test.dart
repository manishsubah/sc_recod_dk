import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';

import '../../fixtures.dart';

class _MockEngineRepository extends Mock implements EngineRepository {}

void main() {
  const folder = '/tmp/RecLite';
  late _MockEngineRepository repo;

  setUp(() => repo = _MockEngineRepository());

  ReadinessCubit build() => ReadinessCubit(repo, outputFolder: folder);

  void stub({EngineInfo engine = testEngineInfo, int freeBytes = 50e9 ~/ 1}) {
    when(() => repo.getEngineInfo()).thenAnswer((_) async => engine);
    when(() => repo.getStorageInfo(folder)).thenAnswer(
      (_) async => StorageInfo(
        path: folder,
        freeBytes: freeBytes,
        totalBytes: 500e9 ~/ 1,
      ),
    );
  }

  blocTest<ReadinessCubit, ReadinessState>(
    'is ready when OS, encoder and disk are fine',
    setUp: stub,
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ReadinessLoading(),
      isA<ReadinessLoaded>()
          .having((s) => s.canRecord, 'canRecord', true)
          .having((s) => s.issues, 'issues', isEmpty),
    ],
  );

  blocTest<ReadinessCubit, ReadinessState>(
    'blocks when the OS is too old',
    setUp: () => stub(engine: testEngineInfo.copyWith(meetsMinimumOs: false)),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ReadinessLoading(),
      isA<ReadinessLoaded>().having((s) => s.canRecord, 'canRecord', false),
    ],
  );

  blocTest<ReadinessCubit, ReadinessState>(
    'blocks when less than 1 GB is free',
    setUp: () => stub(freeBytes: 500 * 1000 * 1000),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ReadinessLoading(),
      isA<ReadinessLoaded>().having((s) => s.canRecord, 'canRecord', false),
    ],
  );

  blocTest<ReadinessCubit, ReadinessState>(
    'only warns when there is no hardware encoder',
    setUp: () =>
        stub(engine: testEngineInfo.copyWith(hasHardwareH264Encoder: false)),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ReadinessLoading(),
      isA<ReadinessLoaded>()
          .having((s) => s.canRecord, 'canRecord', true)
          .having((s) => s.issues.single.isBlocking, 'isBlocking', false),
    ],
  );

  blocTest<ReadinessCubit, ReadinessState>(
    'shows the failure message when the engine fails',
    setUp: () {
      when(() => repo.getEngineInfo())
          .thenThrow(const EngineFailure('engine down'));
      when(() => repo.getStorageInfo(folder)).thenAnswer(
        (_) async =>
            const StorageInfo(path: folder, freeBytes: 1, totalBytes: 1),
      );
    },
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ReadinessLoading(),
      const ReadinessFailed('engine down'),
    ],
  );

  blocTest<ReadinessCubit, ReadinessState>(
    'new recording options apply without re-checking the engine',
    setUp: stub,
    build: build,
    act: (c) async {
      await c.load();
      c.changeOptions(const RecordingOptions(framesPerSecond: 60));
    },
    skip: 2,
    expect: () => [
      isA<ReadinessLoaded>().having(
        (s) => s.options.framesPerSecond,
        'framesPerSecond',
        60,
      ),
    ],
    verify: (_) => verify(() => repo.getEngineInfo()).called(1),
  );
}
