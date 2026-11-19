import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

part 'recording_event.dart';
part 'recording_state.dart';

/// Recording session state machine. Provided once at the shell so a recording
/// survives switching sections.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc(this._recorder) : super(const RecordingIdle()) {
    on<RecordingStartRequested>(_onStart);
    on<RecordingStopRequested>(_onStop);
    on<RecordingPauseRequested>(_onPause);
    on<RecordingResumeRequested>(_onResume);
    on<RecordingDismissed>((_, emit) => emit(const RecordingIdle()));
    on<RecordingRevealRequested>(_onReveal);
    on<_StatusReceived>(_onStatus);
    on<_Interrupted>(_onInterrupted);

    _subscriptions = [
      _recorder.status.listen((s) => add(_StatusReceived(s))),
      _recorder.interruptions.listen((i) => add(_Interrupted(i))),
    ];
  }

  final RecorderRepository _recorder;
  late final List<StreamSubscription<Object>> _subscriptions;

  Future<void> _onStart(
    RecordingStartRequested event,
    Emitter<RecordingState> emit,
  ) async {
    if (state is! RecordingIdle && state is! RecordingFailed) return;
    emit(const RecordingStarting());
    try {
      await _recorder.start(event.config);
      if (state is RecordingStarting) {
        emit(const RecordingActive(RecordingStatus.initial));
      }
    } on Failure catch (f) {
      emit(RecordingFailed(f.message));
    }
  }

  Future<void> _onStop(
    RecordingStopRequested event,
    Emitter<RecordingState> emit,
  ) async {
    final current = state;
    if (current is! RecordingActive) return;
    emit(RecordingStopping(current.status));
    try {
      emit(RecordingFinished(await _recorder.stop()));
    } on Failure catch (f) {
      emit(RecordingFailed(f.message));
    }
  }

  Future<void> _onPause(
    RecordingPauseRequested event,
    Emitter<RecordingState> emit,
  ) async {
    final current = state;
    if (current is! RecordingActive || current.isPaused) return;
    emit(
      current.copyWith(status: current.status.withPhase(RecordingPhase.paused)),
    );
    try {
      await _recorder.pause();
    } on Failure catch (f) {
      emit(current.copyWith(warning: f.message));
    }
  }

  Future<void> _onResume(
    RecordingResumeRequested event,
    Emitter<RecordingState> emit,
  ) async {
    final current = state;
    if (current is! RecordingActive || !current.isPaused) return;
    emit(
      current.copyWith(
        status: current.status.withPhase(RecordingPhase.recording),
      ),
    );
    try {
      await _recorder.resume();
    } on Failure catch (f) {
      emit(current.copyWith(warning: f.message));
    }
  }

  Future<void> _onReveal(
    RecordingRevealRequested event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      await _recorder.reveal(event.path);
    } on Failure catch (f) {
      emit(RecordingFailed(f.message));
    }
  }

  void _onStatus(_StatusReceived event, Emitter<RecordingState> emit) {
    final status = event.status;
    final live =
        status.phase == RecordingPhase.recording ||
        status.phase == RecordingPhase.paused;
    switch (state) {
      case RecordingStarting() when live:
        emit(RecordingActive(status));
      case final RecordingActive active when live:
        emit(active.copyWith(status: status));
      default:
        break;
    }
  }

  void _onInterrupted(_Interrupted event, Emitter<RecordingState> emit) {
    final interruption = event.interruption;
    final current = state;
    if (interruption.isFatal) {
      emit(RecordingFailed(interruption.message));
    } else if (current is RecordingActive) {
      emit(current.copyWith(warning: interruption.message));
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}
