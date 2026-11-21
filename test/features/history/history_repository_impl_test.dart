import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/features/history/data/repositories/history_repository_impl.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite_engine/reclite_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late HistoryRepositoryImpl repo;

  setUp(() {
    root = Directory.systemTemp.createTempSync('reclite_history_');
    repo = HistoryRepositoryImpl(RecliteEngine());
  });

  tearDown(() => root.deleteSync(recursive: true));

  String sep(String a, String b) => '$a${Platform.pathSeparator}$b';

  void writeSession(
    String id, {
    required String status,
    required List<(String file, int ms, int bytes)> parts,
    List<String>? filesOnDisk,
  }) {
    final dir = Directory(sep(root.path, 'RecLite_$id'))..createSync();
    for (final name in filesOnDisk ?? [for (final p in parts) p.$1]) {
      File(sep(dir.path, name)).writeAsStringSync('mp4');
    }
    final segments = [
      for (final (i, p) in parts.indexed)
        '{ "bytes" : ${p.$3}, "durationMs" : ${p.$2}, "file" : "${p.$1}", '
            '"index" : ${i + 1}, "status" : "complete" }',
    ].join(',');
    File(sep(dir.path, 'session.json')).writeAsStringSync('''
{
  "app" : "RecLite",
  "audio" : { "microphone" : true, "system" : true },
  "segmentSeconds" : 900,
  "segments" : [ $segments ],
  "sessionId" : "$id",
  "source" : { "name" : "Built-in Display", "type" : "display" },
  "startedAt" : "${id.substring(0, 10)}T${id.substring(11).replaceAll('-', ':')}Z",
  "status" : "$status",
  "version" : 1
}''');
  }

  test('reads finished recordings, newest first', () async {
    writeSession(
      '2026-11-19_09-00-00',
      status: 'recovered',
      parts: [('a_Part01.mp4', 900000, 500), ('a_Part02.mp4', 4000, 20)],
    );
    writeSession(
      '2026-11-19_10-00-00',
      status: 'completed',
      parts: [('b_Part01.mp4', 13732, 8218731)],
    );

    final list = await repo.list(root.path);

    expect(list, hasLength(2));
    final newest = list.first;
    expect(newest.startedAt, DateTime.utc(2026, 11, 19, 10));
    expect(newest.outcome, RecordingOutcome.completed);
    expect(newest.duration, const Duration(milliseconds: 13732));
    expect(newest.bytes, 8218731);
    expect(newest.sourceName, 'Built-in Display');
    expect(newest.files.single, endsWith('b_Part01.mp4'));

    final older = list.last;
    expect(older.outcome, RecordingOutcome.recovered);
    expect(older.duration, const Duration(milliseconds: 904000));
    expect(older.files.map((f) => f.split(Platform.pathSeparator).last), [
      'a_Part01.mp4',
      'a_Part02.mp4',
    ]);
  });

  test(
    'skips the running recording, broken manifests and empty folders',
    () async {
      writeSession(
        '2026-11-19_11-00-00',
        status: 'recording',
        parts: [('c_Part01.mp4', 1000, 10)],
      );
      Directory(sep(root.path, 'RecLite_broken')).createSync();
      File(sep(sep(root.path, 'RecLite_broken'), 'session.json'))
          .writeAsStringSync('{ not json');
      Directory(sep(root.path, 'Holiday photos')).createSync();

      expect(await repo.list(root.path), isEmpty);
    },
  );

  test('counts only parts that are still on disk', () async {
    writeSession(
      '2026-11-19_12-00-00',
      status: 'completed',
      parts: [('d_Part01.mp4', 1000, 10), ('d_Part02.mp4', 2000, 20)],
      filesOnDisk: ['d_Part02.mp4'],
    );

    final recording = (await repo.list(root.path)).single;
    expect(recording.files.single, endsWith('d_Part02.mp4'));
    expect(recording.duration, const Duration(seconds: 2));
    expect(recording.bytes, 20);
  });

  test('a missing save folder has no recordings', () async {
    expect(await repo.list(sep(root.path, 'missing')), isEmpty);
  });
}
