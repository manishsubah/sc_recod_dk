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

final class RecordingActive extends RecordingState {
  const RecordingActive(this.status);

  final RecordingStatus status;

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [status];
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
