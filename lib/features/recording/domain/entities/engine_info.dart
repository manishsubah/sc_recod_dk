import 'package:equatable/equatable.dart';

class EngineInfo extends Equatable {
  const EngineInfo({
    required this.platformName,
    required this.osVersion,
    required this.minimumOsVersion,
    required this.meetsMinimumOs,
    required this.supportsSystemAudio,
    required this.supportsMicrophoneViaScreenCapture,
    required this.hasHardwareH264Encoder,
    required this.hasHardwareHevcEncoder,
    required this.engineVersion,
  });

  final String platformName;
  final String osVersion;
  final String minimumOsVersion;
  final bool meetsMinimumOs;
  final bool supportsSystemAudio;
  final bool supportsMicrophoneViaScreenCapture;
  final bool hasHardwareH264Encoder;
  final bool hasHardwareHevcEncoder;
  final String engineVersion;

  @override
  List<Object?> get props => [
    platformName,
    osVersion,
    minimumOsVersion,
    meetsMinimumOs,
    supportsSystemAudio,
    supportsMicrophoneViaScreenCapture,
    hasHardwareH264Encoder,
    hasHardwareHevcEncoder,
    engineVersion,
  ];
}
