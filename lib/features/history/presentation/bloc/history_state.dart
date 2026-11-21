part of 'history_cubit.dart';

sealed class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

final class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

final class HistoryLoaded extends HistoryState {
  const HistoryLoaded({
    required this.folder,
    required this.recordings,
    this.error,
  });

  final String folder;
  final List<SavedRecording> recordings;

  /// A failed play/reveal/delete; shown once, then cleared by the next state.
  final String? error;

  HistoryLoaded copyWith({List<SavedRecording>? recordings, String? error}) =>
      HistoryLoaded(
        folder: folder,
        recordings: recordings ?? this.recordings,
        error: error,
      );

  @override
  List<Object?> get props => [folder, recordings, error];
}

final class HistoryFailed extends HistoryState {
  const HistoryFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
