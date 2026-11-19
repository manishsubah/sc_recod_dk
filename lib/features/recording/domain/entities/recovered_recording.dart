import 'package:equatable/equatable.dart';

/// A recording cut off by a crash or power loss, repaired on launch.
class RecoveredRecording extends Equatable {
  const RecoveredRecording({
    required this.sessionDirectory,
    required this.files,
    required this.duration,
  });

  final String sessionDirectory;
  final List<String> files;
  final Duration duration;

  @override
  List<Object?> get props => [sessionDirectory, files, duration];
}
