import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

import '../../fixtures.dart';

class MockRecorderRepository extends Mock implements RecorderRepository {}

void main() {
  late MockRecorderRepository repo;

  setUp(() {
    repo = MockRecorderRepository();
    when(() => repo.hasScreenPermission()).thenAnswer((_) async => true);
    when(() => repo.listDisplays()).thenAnswer((_) async => testDisplays);
  });

  SourcesCubit build() => SourcesCubit(repo);

  blocTest<SourcesCubit, SourcesState>(
    'selects the main display by default',
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const SourcesLoading(),
      const SourcesLoaded(displays: testDisplays, selectedId: 1),
    ],
  );

  blocTest<SourcesCubit, SourcesState>(
    'asks for permission before listing displays',
    setUp: () =>
        when(() => repo.hasScreenPermission()).thenAnswer((_) async => false),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const SourcesLoading(),
      const SourcesPermissionRequired(requested: false),
    ],
    verify: (_) => verifyNever(() => repo.listDisplays()),
  );

  blocTest<SourcesCubit, SourcesState>(
    'denied request points to System Settings',
    setUp: () =>
        when(() => repo.requestScreenPermission())
            .thenAnswer((_) async => false),
    build: build,
    act: (c) => c.requestPermission(),
    expect: () => [const SourcesPermissionRequired(requested: true)],
  );

  blocTest<SourcesCubit, SourcesState>(
    'keeps the chosen display across reloads',
    build: build,
    seed: () => const SourcesLoaded(displays: testDisplays, selectedId: 2),
    act: (c) => c.load(),
    expect: () => [
      const SourcesLoading(),
      const SourcesLoaded(displays: testDisplays, selectedId: 2),
    ],
  );

  blocTest<SourcesCubit, SourcesState>(
    'select switches the display',
    build: build,
    seed: () => const SourcesLoaded(displays: testDisplays, selectedId: 1),
    act: (c) => c.select(2),
    expect: () => [const SourcesLoaded(displays: testDisplays, selectedId: 2)],
  );

  blocTest<SourcesCubit, SourcesState>(
    'engine failure becomes a message',
    setUp: () =>
        when(() => repo.listDisplays())
            .thenThrow(const EngineFailure('Screen capture failed.')),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const SourcesLoading(),
      const SourcesFailed('Screen capture failed.'),
    ],
  );

  group('capture area', () {
    const loaded = SourcesLoaded(displays: testDisplays, selectedId: 1);

    blocTest<SourcesCubit, SourcesState>(
      'selectArea stores the dragged area',
      setUp: () =>
          when(() => repo.selectArea(1)).thenAnswer((_) async => testArea),
      build: build,
      seed: () => loaded,
      act: (c) => c.selectArea(),
      expect: () => [loaded.withArea(testArea)],
    );

    blocTest<SourcesCubit, SourcesState>(
      'cancelling the overlay keeps full screen',
      setUp: () => when(() => repo.selectArea(1)).thenAnswer((_) async => null),
      build: build,
      seed: () => loaded,
      act: (c) => c.selectArea(),
      expect: () => <SourcesState>[],
    );

    blocTest<SourcesCubit, SourcesState>(
      'useFullScreen clears the area',
      build: build,
      seed: () => loaded.withArea(testArea),
      act: (c) => c.useFullScreen(),
      expect: () => [loaded],
    );

    blocTest<SourcesCubit, SourcesState>(
      'switching display clears the area',
      build: build,
      seed: () => loaded.withArea(testArea),
      act: (c) => c.select(2),
      expect: () => [
        const SourcesLoaded(displays: testDisplays, selectedId: 2),
      ],
    );

    blocTest<SourcesCubit, SourcesState>(
      'reload keeps the area for the same display',
      build: build,
      seed: () => loaded.withArea(testArea),
      act: (c) => c.load(),
      expect: () => [const SourcesLoading(), loaded.withArea(testArea)],
    );
  });
}
