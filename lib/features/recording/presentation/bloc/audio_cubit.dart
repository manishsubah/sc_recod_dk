import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

part 'audio_state.dart';

/// Which audio sources the next recording captures.
class AudioCubit extends Cubit<AudioState> {
  AudioCubit(this._recorder) : super(const AudioState());

  final RecorderRepository _recorder;

  void setSystemAudio(bool on) => emit(state.copyWith(systemAudio: on));

  /// Turning the microphone on asks for permission when needed; if refused it stays off.
  Future<void> setMicrophone(bool on) async {
    if (!on) {
      emit(state.copyWith(microphone: false, microphoneBlocked: false));
      return;
    }
    try {
      final granted =
          await _recorder.hasMicrophonePermission() ||
          await _recorder.requestMicrophonePermission();
      emit(state.copyWith(microphone: granted, microphoneBlocked: !granted));
    } on Failure {
      emit(state.copyWith(microphone: false, microphoneBlocked: true));
    }
  }

  Future<void> openMicrophoneSettings() async {
    try {
      await _recorder.openMicrophoneSettings();
    } on Failure {
      // Opening Settings is best-effort; the hint text already explains where to go.
    }
  }
}
