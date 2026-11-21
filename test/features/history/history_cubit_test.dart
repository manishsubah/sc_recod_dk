import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';

class MockHistoryRepository extends Mock implements HistoryRepository {}

final _older = SavedRecording(
  manifestPath: '/data/Sessions/RecLite_2026-11-19_09-00-00.json',
  startedAt: DateTime.utc(2026, 11, 19, 9),
  duration: const Duration(minutes: 20),
  bytes: 900000000,
  files: const [
    '/rec/RecLite_2026-11-19_09-00-00_Part01.mp4',
    '/rec/RecLite_2026-11-19_09-00-00_Part02.mp4',
  ],
  sourceName: 'Built-in Display',
  outcome: RecordingOutcome.recovered,
);

final _newer = SavedRecording(
  manifestPath: '/data/Sessions/RecLite_2026-11-19_10-00-00.json',
  startedAt: DateTime.utc(2026, 11, 19, 10),
  duration: const Duration(seconds: 30),
  bytes: 20000000,
  files: const ['/rec/RecLite_2026-11-19_10-00-00.mp4'],
  sourceName: 'Built-in Display',
  outcome: RecordingOutcome.completed,
);

void main() {
  late MockHistoryRepository repo;

  setUpAll(() => registerFallbackValue(_newer));

  setUp(() {
    repo = MockHistoryRepository();
    when(() => repo.list('/rec')).thenAnswer((_) async => [_newer, _older]);
  });

  blocTest<HistoryCubit, HistoryState>(
    'lists recordings in the save folder',
    build: () => HistoryCubit(repo, '/rec'),
    act: (c) => c.load(),
    expect: () => [
      const HistoryLoading(),
      HistoryLoaded(folder: '/rec', recordings: [_newer, _older]),
    ],
  );

  blocTest<HistoryCubit, HistoryState>(
    'switches to a new save folder',
    setUp: () =>
        when(() => repo.list('/other')).thenAnswer((_) async => const []),
    build: () => HistoryCubit(repo, '/rec'),
    act: (c) => c.load('/other'),
    expect: () => [
      const HistoryLoading(),
      const HistoryLoaded(folder: '/other', recordings: []),
    ],
  );

  blocTest<HistoryCubit, HistoryState>(
    'shows a user-safe message when the folder cannot be read',
    setUp: () => when(() => repo.list('/rec'))
        .thenThrow(const StorageFailure('The save folder could not be read.')),
    build: () => HistoryCubit(repo, '/rec'),
    act: (c) => c.load(),
    expect: () => [
      const HistoryLoading(),
      const HistoryFailed('The save folder could not be read.'),
    ],
  );

  blocTest<HistoryCubit, HistoryState>(
    'plays and reveals the first part',
    setUp: () {
      when(() => repo.play(any())).thenAnswer((_) async {});
      when(() => repo.reveal(any())).thenAnswer((_) async {});
    },
    build: () => HistoryCubit(repo, '/rec'),
    act: (c) async {
      await c.play(_older);
      await c.reveal(_older);
    },
    verify: (_) {
      verify(() => repo.play(_older.files.first)).called(1);
      verify(() => repo.reveal(_older.files.first)).called(1);
    },
  );

  blocTest<HistoryCubit, HistoryState>(
    'moves a whole recording to the bin and drops it from the list',
    setUp: () => when(() => repo.moveToTrash(any())).thenAnswer((_) async {}),
    build: () => HistoryCubit(repo, '/rec'),
    seed: () => HistoryLoaded(folder: '/rec', recordings: [_newer, _older]),
    act: (c) => c.moveToTrash(_older),
    expect: () => [
      HistoryLoaded(folder: '/rec', recordings: [_newer]),
    ],
    verify: (_) => verify(() => repo.moveToTrash(_older)).called(1),
  );

  blocTest<HistoryCubit, HistoryState>(
    'keeps the recording and shows the error once when the bin fails',
    setUp: () => when(() => repo.moveToTrash(any()))
        .thenThrow(const StorageFailure('The recording could not be removed.')),
    build: () => HistoryCubit(repo, '/rec'),
    seed: () => HistoryLoaded(folder: '/rec', recordings: [_newer]),
    act: (c) => c.moveToTrash(_newer),
    expect: () => [
      HistoryLoaded(
        folder: '/rec',
        recordings: [_newer],
        error: 'The recording could not be removed.',
      ),
      HistoryLoaded(folder: '/rec', recordings: [_newer]),
    ],
  );
}
