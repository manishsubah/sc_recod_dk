// Regenerate (from packages/reclite_engine): dart run pigeon --input pigeons/engine_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'reclite_engine',
    swiftOut: 'macos/reclite_engine/Sources/reclite_engine/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'reclite_engine'),
  ),
)
enum HostPlatform { macos, windows }

class EngineCapabilities {
  EngineCapabilities({
    required this.platform,
    required this.osVersion,
    required this.minimumOsVersion,
    required this.meetsMinimumOs,
    required this.supportsSystemAudio,
    required this.supportsMicrophoneViaScreenCapture,
    required this.hasHardwareH264Encoder,
    required this.hasHardwareHevcEncoder,
    required this.engineVersion,
  });

  HostPlatform platform;

  String osVersion;
  String minimumOsVersion;
  bool meetsMinimumOs;
  bool supportsSystemAudio;
  bool supportsMicrophoneViaScreenCapture;

  bool hasHardwareH264Encoder;
  bool hasHardwareHevcEncoder;
  String engineVersion;
}

class DiskSpace {
  DiskSpace({required this.freeBytes, required this.totalBytes});

  int freeBytes;
  int totalBytes;
}

@HostApi()
abstract class EngineHostApi {
  EngineCapabilities getCapabilities();

  DiskSpace getDiskSpace(String path);
}
