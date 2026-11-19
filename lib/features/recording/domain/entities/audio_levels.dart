import 'package:equatable/equatable.dart';

/// Peak levels, 0 (silent) to 1 (full scale).
class AudioLevels extends Equatable {
  const AudioLevels({required this.system, required this.microphone});

  static const silent = AudioLevels(system: 0, microphone: 0);

  final double system;
  final double microphone;

  @override
  List<Object?> get props => [system, microphone];
}
