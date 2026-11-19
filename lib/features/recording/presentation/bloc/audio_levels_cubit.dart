import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

/// Live meter values. Kept apart from other state so only the meters rebuild ~15×/s.
class AudioLevelsCubit extends Cubit<AudioLevels> {
  AudioLevelsCubit(RecorderRepository recorder) : super(AudioLevels.silent) {
    _subscription = recorder.audioLevels.listen(emit);
  }

  late final StreamSubscription<AudioLevels> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
