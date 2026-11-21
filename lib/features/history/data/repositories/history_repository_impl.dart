import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

/// Recordings are described by manifests in the engine's sessions folder; their
/// videos sit directly in whichever save folder was used. Recordings made before
/// that layout have a folder of their own with a `session.json` inside.
class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._engine);

  static const legacyManifestName = 'session.json';

  final RecliteEngine _engine;

  @override
  Future<List<SavedRecording>> list(String folder) async {
    final recordings = <SavedRecording>[
      ...await _fromSessions(),
      ...await _legacyIn(folder),
    ];
    final seen = <String>{};
    final unique = [
      for (final r in recordings)
        if (seen.add(r.files.first)) r,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return unique;
  }

  Future<List<SavedRecording>> _fromSessions() async {
    final String sessions;
    try {
      sessions = await _engine.getSessionsDirectory();
    } on PlatformException {
      return const [];
    }
    final directory = Directory(sessions);
    if (!await directory.exists()) return const [];
    final recordings = <SavedRecording>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final recording = await readManifest(entity);
        if (recording != null) recordings.add(recording);
      }
    } on FileSystemException {
      throw const StorageFailure('RecLite could not read its recordings list.');
    }
    return recordings;
  }

  Future<List<SavedRecording>> _legacyIn(String folder) async {
    final root = Directory(folder);
    if (!await root.exists()) return const [];
    final recordings = <SavedRecording>[];
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final manifest = File(
          '${entity.path}${Platform.pathSeparator}$legacyManifestName',
        );
        final recording = await readManifest(manifest, videosIn: entity.path);
        if (recording != null) recordings.add(recording);
      }
    } on FileSystemException {
      throw const StorageFailure('The save folder could not be read.');
    }
    return recordings;
  }

  /// Null for anything that is not a finished recording with videos still on
  /// disk. [videosIn] marks an old-style manifest that sits next to its videos.
  static Future<SavedRecording?> readManifest(
    File manifest, {
    String? videosIn,
  }) async {
    try {
      if (!await manifest.exists()) return null;
      final json = jsonDecode(await manifest.readAsString());
      if (json is! Map<String, Object?>) return null;
      final folder = videosIn ?? json['directory'];
      if (folder is! String) return null;
      return _parse(
        json,
        manifestPath: manifest.path,
        folder: folder,
        inOwnFolder: videosIn != null,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static SavedRecording? _parse(
    Map<String, Object?> json, {
    required String manifestPath,
    required String folder,
    required bool inOwnFolder,
  }) {
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
      final path = '$folder${Platform.pathSeparator}$name';
      if (!File(path).existsSync()) continue;
      files.add(path);
      durationMs += _int(segment['durationMs']);
      bytes += _int(segment['bytes']);
    }
    if (files.isEmpty) return null;

    final source = json['source'];
    return SavedRecording(
      manifestPath: manifestPath,
      inOwnFolder: inOwnFolder,
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
  Future<void> moveToTrash(SavedRecording recording) => _guard(() async {
    if (recording.inOwnFolder) {
      await _engine.moveToTrash(File(recording.manifestPath).parent.path);
      return;
    }
    for (final file in recording.files) {
      await _engine.moveToTrash(file);
    }
    // Only bookkeeping: the videos above can still be restored from the bin.
    try {
      await File(recording.manifestPath).delete();
    } on FileSystemException {
      // Without its videos the manifest no longer shows up in History.
    }
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }
}
