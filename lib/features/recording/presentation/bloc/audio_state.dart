part of 'audio_cubit.dart';

/// A settings form has no loading/failed phase, so this is a single state class.
final class AudioState extends Equatable {
  const AudioState({
    this.systemAudio = true,
    this.microphone = false,
    this.microphoneBlocked = false,
  });

  final bool systemAudio;
  final bool microphone;

  /// The user refused microphone access; only System Settings can change it now.
  final bool microphoneBlocked;

  AudioState copyWith({
    bool? systemAudio,
    bool? microphone,
    bool? microphoneBlocked,
  }) => AudioState(
    systemAudio: systemAudio ?? this.systemAudio,
    microphone: microphone ?? this.microphone,
    microphoneBlocked: microphoneBlocked ?? this.microphoneBlocked,
  );

  @override
  List<Object?> get props => [systemAudio, microphone, microphoneBlocked];
}
