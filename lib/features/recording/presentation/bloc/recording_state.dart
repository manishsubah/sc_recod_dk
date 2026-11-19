part of 'recording_bloc.dart';

sealed class RecordingState extends Equatable {
  const RecordingState();

  bool get isBusy => false;

  @override
  List<Object?> get props => [];
}

final class RecordingIdle extends RecordingState {
  const RecordingIdle();
}

final class RecordingStarting extends RecordingState {
  const RecordingStarting();

  @override
  bool get isBusy => true;
}

/// Recording or paused. [warning] is a non-fatal notice such as low disk space.
final class RecordingActive extends RecordingState {
  const RecordingActive(this.status, {this.warning});

  final RecordingStatus status;
  final String? warning;

  bool get isPaused => status.phase == RecordingPhase.paused;

  RecordingActive copyWith({RecordingStatus? status, String? warning}) =>
      RecordingActive(status ?? this.status, warning: warning ?? this.warning);

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [status, warning];
}

final class RecordingStopping extends RecordingState {
  const RecordingStopping(this.lastStatus);

  final RecordingStatus lastStatus;

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [lastStatus];
}

final class RecordingFinished extends RecordingState {
  const RecordingFinished(this.result);

  final RecordingResult result;

  @override
  List<Object?> get props => [result];
}

final class RecordingFailed extends RecordingState {
  const RecordingFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
