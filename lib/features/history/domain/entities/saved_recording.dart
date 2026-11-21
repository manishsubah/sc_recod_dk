import 'package:equatable/equatable.dart';

enum RecordingOutcome {
  completed,

  /// Repaired after a crash or power loss.
  recovered,

  /// Stopped early (e.g. by an error) and not repaired.
  interrupted,
}

/// One past recording, read from its manifest.
class SavedRecording extends Equatable {
  const SavedRecording({
    required this.manifestPath,
    required this.startedAt,
    required this.duration,
    required this.bytes,
    required this.files,
    required this.sourceName,
    required this.outcome,
    this.inOwnFolder = false,
  });

  /// The recording's metadata file (in RecLite's data folder).
  final String manifestPath;

  /// Recordings from before the flat layout live in a folder of their own.
  final bool inOwnFolder;
  final DateTime startedAt;
  final Duration duration;
  final int bytes;

  /// MP4 parts in order; only files that still exist.
  final List<String> files;
  final String sourceName;
  final RecordingOutcome outcome;

  @override
  List<Object?> get props => [
    manifestPath,
    inOwnFolder,
    startedAt,
    duration,
    bytes,
    files,
    sourceName,
    outcome,
  ];
}
