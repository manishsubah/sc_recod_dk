import 'package:equatable/equatable.dart';

enum RecordingPhase { idle, starting, recording, paused, stopping }

class RecordingStatus extends Equatable {
  const RecordingStatus({
    required this.phase,
    required this.elapsed,
    required this.segmentIndex,
    required this.bytesWritten,
    required this.droppedFrames,
  });

  static const initial = RecordingStatus(
    phase: RecordingPhase.recording,
    elapsed: Duration.zero,
    segmentIndex: 1,
    bytesWritten: 0,
    droppedFrames: 0,
  );

  final RecordingPhase phase;
  final Duration elapsed;
  final int segmentIndex;
  final int bytesWritten;
  final int droppedFrames;

  RecordingStatus withPhase(RecordingPhase phase) => RecordingStatus(
    phase: phase,
    elapsed: elapsed,
    segmentIndex: segmentIndex,
    bytesWritten: bytesWritten,
    droppedFrames: droppedFrames,
  );

  @override
  List<Object?> get props => [
    phase,
    elapsed,
    segmentIndex,
    bytesWritten,
    droppedFrames,
  ];
}
