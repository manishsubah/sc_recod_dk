import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/features/history/data/repositories/history_repository_impl.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite_engine/reclite_engine.dart';

class MockRecliteEngine extends Mock implements RecliteEngine {}

void main() {
  late Directory root;
  late Directory sessions;
  late Directory videos;
  late MockRecliteEngine engine;
  late HistoryRepositoryImpl repo;

  String join(String a, String b) => '$a${Platform.pathSeparator}$b';

  setUp(() {
    root = Directory.systemTemp.createTempSync('reclite_history_');
    sessions = Directory(join(root.path, 'Sessions'))..createSync();
    videos = Directory(join(root.path, 'Videos'))..createSync();
    engine = MockRecliteEngine();
    when(() => engine.getSessionsDirectory())
        .thenAnswer((_) async => sessions.path);
    when(() => engine.moveToTrash(any())).thenAnswer((_) async {});
    repo = HistoryRepositoryImpl(engine);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// A manifest like the engines write. [folder] is set for the flat layout
  /// and left out for an old-style session.json inside the recording's folder.
  String manifest(
    String id, {
    required String status,
    required List<(String file, int ms, int bytes)> parts,
    String? folder,
  }) => jsonEncode({
    'app': 'RecLite',
    'directory': ?folder,
    'segments': [
      for (final (i, p) in parts.indexed)
        {
          'bytes': p.$3,
          'durationMs': p.$2,
          'file': p.$1,
          'index': i + 1,
          'status': 'complete',
        },
    ],
    'sessionId': id,
    'source': {'name': 'Built-in Display', 'type': 'display'},
    'startedAt':
        '${id.substring(0, 10)}T${id.substring(11).replaceAll('-', ':')}Z',
    'status': status,
    'version': 1,
  });

  void writeVideos(Directory folder, List<String> names) {
    for (final name in names) {
      File(join(folder.path, name)).writeAsStringSync('mp4');
    }
  }

  File writeManifest(String id, String json) =>
      File(join(sessions.path, 'RecLite_$id.json'))..writeAsStringSync(json);

  Directory oldStyleRecording(String id) {
    final folder = Directory(join(videos.path, 'RecLite_$id'))..createSync();
    writeVideos(folder, ['RecLite_${id}_Part01.mp4']);
    File(join(folder.path, 'session.json')).writeAsStringSync(
      manifest(
        id,
        status: 'completed',
        parts: [('RecLite_${id}_Part01.mp4', 1000, 10)],
      ),
    );
    return folder;
  }

  test('lists flat recordings from any folder, newest first', () async {
    writeVideos(videos, [
      'RecLite_2026-11-19_09-00-00_Part01.mp4',
      'RecLite_2026-11-19_09-00-00_Part02.mp4',
      'RecLite_2026-11-19_10-00-00.mp4',
    ]);
    writeManifest(
      '2026-11-19_09-00-00',
      manifest(
        '2026-11-19_09-00-00',
        status: 'recovered',
        folder: videos.path,
        parts: [
          ('RecLite_2026-11-19_09-00-00_Part01.mp4', 900000, 500),
          ('RecLite_2026-11-19_09-00-00_Part02.mp4', 4000, 20),
        ],
      ),
    );
    writeManifest(
      '2026-11-19_10-00-00',
      manifest(
        '2026-11-19_10-00-00',
        status: 'completed',
        folder: videos.path,
        parts: [('RecLite_2026-11-19_10-00-00.mp4', 13732, 8218731)],
      ),
    );

    final list = await repo.list(join(root.path, 'some other save folder'));

    expect(list, hasLength(2));
    final newest = list.first;
    expect(newest.startedAt, DateTime.utc(2026, 11, 19, 10));
    expect(newest.outcome, RecordingOutcome.completed);
    expect(newest.duration, const Duration(milliseconds: 13732));
    expect(newest.bytes, 8218731);
    expect(newest.inOwnFolder, isFalse);
    expect(
      newest.files.single,
      join(videos.path, 'RecLite_2026-11-19_10-00-00.mp4'),
    );

    final older = list.last;
    expect(older.outcome, RecordingOutcome.recovered);
    expect(older.duration, const Duration(milliseconds: 904000));
    expect(older.files, hasLength(2));
  });

  test('still lists recordings in their own folder (older layout)', () async {
    oldStyleRecording('2026-11-18_08-00-00');

    final recording = (await repo.list(videos.path)).single;
    expect(recording.inOwnFolder, isTrue);
    expect(
      recording.files.single,
      endsWith('RecLite_2026-11-18_08-00-00_Part01.mp4'),
    );
  });

  test(
    'skips running recordings, broken manifests and deleted videos',
    () async {
      writeVideos(videos, ['RecLite_2026-11-19_11-00-00_Part01.mp4']);
      writeManifest(
        '2026-11-19_11-00-00',
        manifest(
          '2026-11-19_11-00-00',
          status: 'recording',
          folder: videos.path,
          parts: [('RecLite_2026-11-19_11-00-00_Part01.mp4', 1000, 10)],
        ),
      );
      writeManifest('broken', '{ not json');
      writeManifest(
        '2026-11-19_12-00-00',
        manifest(
          '2026-11-19_12-00-00',
          status: 'completed',
          folder: videos.path,
          parts: [('RecLite_2026-11-19_12-00-00.mp4', 1000, 10)],
        ),
      );

      expect(await repo.list(videos.path), isEmpty);
    },
  );

  test('moving to the bin bins the videos and drops the manifest', () async {
    writeVideos(videos, ['RecLite_2026-11-19_10-00-00.mp4']);
    final file = writeManifest(
      '2026-11-19_10-00-00',
      manifest(
        '2026-11-19_10-00-00',
        status: 'completed',
        folder: videos.path,
        parts: [('RecLite_2026-11-19_10-00-00.mp4', 1000, 10)],
      ),
    );
    final recording = (await repo.list(videos.path)).single;

    await repo.moveToTrash(recording);

    verify(() => engine.moveToTrash(recording.files.single)).called(1);
    expect(file.existsSync(), isFalse);
  });

  test('an old-style recording is binned as its whole folder', () async {
    final folder = oldStyleRecording('2026-11-18_08-00-00');
    final recording = (await repo.list(videos.path)).single;

    await repo.moveToTrash(recording);

    verify(() => engine.moveToTrash(folder.path)).called(1);
  });

  test('no sessions folder still lists old-style recordings', () async {
    when(() => engine.getSessionsDirectory())
        .thenAnswer((_) async => join(root.path, 'missing'));
    oldStyleRecording('2026-11-18_08-00-00');

    expect(await repo.list(videos.path), hasLength(1));
  });
}
