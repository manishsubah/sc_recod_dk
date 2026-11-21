import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';

import '../../fixtures.dart';

class MockRecorderRepository extends Mock implements RecorderRepository {}

void main() {
  late MockRecorderRepository repo;

  setUp(() => repo = MockRecorderRepository());

  RecoveryCubit build() => RecoveryCubit(repo);

  blocTest<RecoveryCubit, RecoveryState>(
    'reports recovered recordings',
    setUp: () =>
        when(() => repo.recover()).thenAnswer((_) async => [testRecovered]),
    build: build,
    act: (c) => c.check(),
    expect: () => [
      const RecoveryFound([testRecovered]),
    ],
  );

  blocTest<RecoveryCubit, RecoveryState>(
    'stays quiet when nothing was interrupted',
    setUp: () => when(() => repo.recover()).thenAnswer((_) async => []),
    build: build,
    act: (c) => c.check(),
    expect: () => <RecoveryState>[],
  );

  blocTest<RecoveryCubit, RecoveryState>(
    'engine failure is not shown (next launch retries)',
    setUp: () =>
        when(() => repo.recover()).thenThrow(const StorageFailure('no')),
    build: build,
    act: (c) => c.check(),
    expect: () => <RecoveryState>[],
  );

  blocTest<RecoveryCubit, RecoveryState>(
    'dismiss hides the banner',
    build: build,
    seed: () => const RecoveryFound([testRecovered]),
    act: (c) => c.dismiss(),
    expect: () => [const RecoveryIdle()],
  );
}
