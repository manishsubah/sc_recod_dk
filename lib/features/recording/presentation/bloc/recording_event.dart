part of 'recording_bloc.dart';

sealed class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => [];
}

final class RecordingStartRequested extends RecordingEvent {
  const RecordingStartRequested(this.config);

  final RecordingConfig config;

  @override
  List<Object?> get props => [config];
}

final class RecordingStopRequested extends RecordingEvent {
  const RecordingStopRequested();
}

final class RecordingPauseRequested extends RecordingEvent {
  const RecordingPauseRequested();
}

final class RecordingResumeRequested extends RecordingEvent {
  const RecordingResumeRequested();
}

final class RecordingDismissed extends RecordingEvent {
  const RecordingDismissed();
}

final class RecordingRevealRequested extends RecordingEvent {
  const RecordingRevealRequested(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

final class _StatusReceived extends RecordingEvent {
  const _StatusReceived(this.status);

  final RecordingStatus status;

  @override
  List<Object?> get props => [status];
}

final class _Interrupted extends RecordingEvent {
  const _Interrupted(this.interruption);

  final RecordingInterruption interruption;

  @override
  List<Object?> get props => [interruption];
}
