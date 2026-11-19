import 'package:equatable/equatable.dart';

class RecordingResult extends Equatable {
  const RecordingResult({
    required this.sessionDirectory,
    required this.files,
    required this.duration,
    required this.bytesWritten,
  });

  final String sessionDirectory;
  final List<String> files;
  final Duration duration;
  final int bytesWritten;

  @override
  List<Object?> get props => [sessionDirectory, files, duration, bytesWritten];
}
