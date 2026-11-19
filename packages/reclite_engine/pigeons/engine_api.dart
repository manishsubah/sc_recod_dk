// Source of truth for the Flutter <-> native engine contract.
//
// Regenerate after editing (from packages/reclite_engine):
//   dart run pigeon --input pigeons/engine_api.dart
//
// Rules (see docs/PLAN.md §14):
//   * Only small, typed messages cross this boundary. Never video/audio data.
//   * Every method here is implemented on BOTH macOS (Swift) and Windows (C++).
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

/// What this machine and OS can do. Queried once at startup.
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

  /// Human-readable OS version, e.g. "14.5.0" or "10.0.22631".
  String osVersion;

  /// Lowest OS version RecLite supports on this platform.
  String minimumOsVersion;
  bool meetsMinimumOs;

  /// System ("internal") audio capture is available.
  bool supportsSystemAudio;

  /// macOS 15+: microphone can be captured by ScreenCaptureKit on the same
  /// clock as the screen. Otherwise a separate mic pipeline is used.
  bool supportsMicrophoneViaScreenCapture;

  bool hasHardwareH264Encoder;
  bool hasHardwareHevcEncoder;
  String engineVersion;
}

class DiskSpace {
  DiskSpace({required this.freeBytes, required this.totalBytes});

  /// Bytes available for new files on the volume containing the path.
  int freeBytes;
  int totalBytes;
}

@HostApi()
abstract class EngineHostApi {
  EngineCapabilities getCapabilities();

  /// Free/total space of the volume holding [path].
  /// Throws a PlatformException with code "invalid_path" if it does not exist.
  DiskSpace getDiskSpace(String path);
}
