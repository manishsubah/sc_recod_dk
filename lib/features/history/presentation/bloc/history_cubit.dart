import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';

part 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._history, this._folder) : super(const HistoryLoading());

  final HistoryRepository _history;
  String _folder;

  Future<void> load([String? folder]) async {
    if (folder != null) _folder = folder;
    emit(const HistoryLoading());
    await refresh();
  }

  /// Re-reads the folder without showing a spinner.
  Future<void> refresh() async {
    try {
      final recordings = await _history.list(_folder);
      emit(HistoryLoaded(folder: _folder, recordings: recordings));
    } on Failure catch (e) {
      emit(HistoryFailed(e.message));
    }
  }

  Future<void> play(SavedRecording recording) =>
      _act(() => _history.play(recording.files.first));

  Future<void> reveal(SavedRecording recording) =>
      _act(() => _history.reveal(recording.files.first));

  Future<void> moveToTrash(SavedRecording recording) => _act(() async {
    await _history.moveToTrash(recording);
    final current = state;
    if (current is HistoryLoaded) {
      emit(
        current.copyWith(
          recordings: [
            for (final r in current.recordings)
              if (r != recording) r,
          ],
        ),
      );
    }
  });

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on Failure catch (e) {
      final current = state;
      if (current is HistoryLoaded) {
        emit(current.copyWith(error: e.message));
        emit(current.copyWith());
      }
    }
  }
}
