import 'package:equatable/equatable.dart';

/// A recording cut off by a crash or power loss, repaired on launch.
class RecoveredRecording extends Equatable {
  const RecoveredRecording({
    required this.folder,
    required this.files,
    required this.duration,
  });

  /// The save folder holding [files].
  final String folder;
  final List<String> files;
  final Duration duration;

  @override
  List<Object?> get props => [folder, files, duration];
}
