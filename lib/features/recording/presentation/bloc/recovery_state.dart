part of 'recovery_cubit.dart';

sealed class RecoveryState extends Equatable {
  const RecoveryState();

  @override
  List<Object?> get props => [];
}

final class RecoveryIdle extends RecoveryState {
  const RecoveryIdle();
}

final class RecoveryFound extends RecoveryState {
  const RecoveryFound(this.recordings);

  final List<RecoveredRecording> recordings;

  @override
  List<Object?> get props => [recordings];
}
