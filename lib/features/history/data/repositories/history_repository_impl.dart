import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._engine);

  static const manifestName = 'session.json';

  final RecliteEngine _engine;

  @override
  Future<List<SavedRecording>> list(String folder) async {
    final root = Directory(folder);
    if (!await root.exists()) return const [];
    final recordings = <SavedRecording>[];
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final recording = await readSession(entity);
        if (recording != null) recordings.add(recording);
      }
    } on FileSystemException {
      throw const StorageFailure('The save folder could not be read.');
    }
    recordings.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return recordings;
  }

  /// Null for folders that are not a finished RecLite recording.
  static Future<SavedRecording?> readSession(Directory session) async {
    final manifest = File(
      '${session.path}${Platform.pathSeparator}$manifestName',
    );
    try {
      if (!await manifest.exists()) return null;
      final json = jsonDecode(await manifest.readAsString());
      if (json is! Map<String, Object?>) return null;
      return _parse(session.path, json);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static SavedRecording? _parse(String directory, Map<String, Object?> json) {
    final status = json['status'];
    if (status == 'recording') return null;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (startedAt == null) return null;

    final segments =
        (json['segments'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .toList()
          ..sort((a, b) => _int(a['index']).compareTo(_int(b['index'])));
    final files = <String>[];
    var durationMs = 0;
    var bytes = 0;
    for (final segment in segments) {
      final name = segment['file'];
      if (name is! String) continue;
      final path = '$directory${Platform.pathSeparator}$name';
      if (!File(path).existsSync()) continue;
      files.add(path);
      durationMs += _int(segment['durationMs']);
      bytes += _int(segment['bytes']);
    }
    if (files.isEmpty) return null;

    final source = json['source'];
    return SavedRecording(
      sessionDirectory: directory,
      startedAt: startedAt,
      duration: Duration(milliseconds: durationMs),
      bytes: bytes,
      files: files,
      sourceName: source is Map<String, Object?>
          ? source['name'] as String? ?? ''
          : '',
      outcome: switch (status) {
        'completed' => RecordingOutcome.completed,
        'recovered' => RecordingOutcome.recovered,
        _ => RecordingOutcome.interrupted,
      },
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  @override
  Future<void> play(String file) => _guard(() => _engine.openPath(file));

  @override
  Future<void> reveal(String path) =>
      _guard(() => _engine.revealInFileManager(path));

  @override
  Future<void> moveToTrash(String sessionDirectory) =>
      _guard(() => _engine.moveToTrash(sessionDirectory));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }
}
