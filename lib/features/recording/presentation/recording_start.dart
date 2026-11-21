import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';

/// What the Start button records right now (also used by the global shortcut).
/// Null while recording is not possible (not ready, no screen access, …).
RecordingConfig? currentRecordingConfig(BuildContext context) {
  final readiness = context.read<ReadinessCubit>().state;
  final sources = context.read<SourcesCubit>().state;
  if (readiness is! ReadinessLoaded ||
      !readiness.canRecord ||
      sources is! SourcesLoaded) {
    return null;
  }
  final audio = context.read<AudioCubit>().state;
  final options = readiness.options;
  return RecordingConfig(
    displayId: sources.selectedId,
    area: sources.area,
    windowId: sources.window?.id,
    captureSystemAudio: audio.systemAudio,
    captureMicrophone: audio.microphone,
    outputFolder: readiness.storage.path,
    segmentDuration: options.segmentDuration,
    framesPerSecond: options.framesPerSecond,
    maxHeight: options.maxHeight,
    showCursor: options.showCursor,
  );
}
