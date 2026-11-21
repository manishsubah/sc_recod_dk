part of 'readiness_cubit.dart';

sealed class ReadinessState extends Equatable {
  const ReadinessState();

  @override
  List<Object?> get props => [];
}

final class ReadinessLoading extends ReadinessState {
  const ReadinessLoading();
}

final class ReadinessLoaded extends ReadinessState {
  const ReadinessLoaded({
    required this.engine,
    required this.storage,
    required this.issues,
    this.options = const RecordingOptions(),
  });

  final EngineInfo engine;
  final StorageInfo storage;
  final List<ReadinessIssue> issues;
  final RecordingOptions options;

  bool get canRecord => issues.every((i) => !i.isBlocking);

  @override
  List<Object?> get props => [engine, storage, issues, options];
}

final class ReadinessFailed extends ReadinessState {
  const ReadinessFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ReadinessIssue extends Equatable {
  const ReadinessIssue.blocking(this.message) : isBlocking = true;
  const ReadinessIssue.warning(this.message) : isBlocking = false;

  final String message;
  final bool isBlocking;

  @override
  List<Object?> get props => [message, isBlocking];
}
