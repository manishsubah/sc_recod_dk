import 'package:equatable/equatable.dart';

class RecordingResult extends Equatable {
  const RecordingResult({
    required this.folder,
    required this.files,
    required this.duration,
    required this.bytesWritten,
  });

  /// The save folder holding [files].
  final String folder;
  final List<String> files;
  final Duration duration;
  final int bytesWritten;

  @override
  List<Object?> get props => [folder, files, duration, bytesWritten];
}
