import 'package:reclite/features/recording/domain/entities/engine_info.dart';

const testEngineInfo = EngineInfo(
  platformName: 'macOS',
  osVersion: '15.1.0',
  minimumOsVersion: '13.0',
  meetsMinimumOs: true,
  supportsSystemAudio: true,
  supportsMicrophoneViaScreenCapture: true,
  hasHardwareH264Encoder: true,
  hasHardwareHevcEncoder: true,
  engineVersion: '0.1.0',
);

extension EngineInfoCopy on EngineInfo {
  EngineInfo copyWith({bool? meetsMinimumOs, bool? hasHardwareH264Encoder}) =>
      EngineInfo(
        platformName: platformName,
        osVersion: osVersion,
        minimumOsVersion: minimumOsVersion,
        meetsMinimumOs: meetsMinimumOs ?? this.meetsMinimumOs,
        supportsSystemAudio: supportsSystemAudio,
        supportsMicrophoneViaScreenCapture: supportsMicrophoneViaScreenCapture,
        hasHardwareH264Encoder:
            hasHardwareH264Encoder ?? this.hasHardwareH264Encoder,
        hasHardwareHevcEncoder: hasHardwareHevcEncoder,
        engineVersion: engineVersion,
      );
}
