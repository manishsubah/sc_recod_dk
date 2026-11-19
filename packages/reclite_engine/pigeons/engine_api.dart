// Regenerate (from packages/reclite_engine): dart run pigeon --input pigeons/engine_api.dart
// Commit the output as generated; do not format it.
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
    required this.supportsRecording,
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

  /// False while this platform's recording pipeline is not implemented yet.
  bool supportsRecording;
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

class EngineDisplay {
  EngineDisplay({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isMain,
  });

  int id;
  String name;

  /// Native pixel size (Retina/HiDPI included).
  int width;
  int height;
  bool isMain;
}

/// A rectangle on one display, in points, origin at the display's top-left.
class EngineCaptureArea {
  EngineCaptureArea({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

class EngineRecordingRequest {
  EngineRecordingRequest({
    required this.displayId,
    required this.outputDirectory,
    required this.framesPerSecond,
    required this.maxHeight,
    required this.captureSystemAudio,
    required this.captureMicrophone,
    required this.segmentSeconds,
    this.area,
  });

  int displayId;

  /// Everything the computer plays (meetings, videos), excluding RecLite itself.
  bool captureSystemAudio;

  /// Default input device, mixed with system audio into one AAC track.
  bool captureMicrophone;

  /// Recorded time (pauses excluded) per MP4 part, e.g. 900 for 15 minutes.
  int segmentSeconds;

  /// Null records the whole display.
  EngineCaptureArea? area;

  /// Parent folder; the engine creates a per-session folder inside it.
  String outputDirectory;
  int framesPerSecond;

  /// Output is scaled down (GPU) to at most this height, keeping aspect ratio.
  int maxHeight;
}

class EngineRecordingSession {
  EngineRecordingSession({
    required this.sessionDirectory,
    required this.width,
    required this.height,
  });

  String sessionDirectory;
  int width;
  int height;
}

enum EngineRecordingPhase { idle, starting, recording, paused, stopping }

/// A recording that was interrupted (crash, power loss) and repaired on launch.
class EngineRecoveredSession {
  EngineRecoveredSession({
    required this.sessionDirectory,
    required this.files,
    required this.durationMs,
  });

  String sessionDirectory;
  List<String> files;
  int durationMs;
}

class EngineRecordingStatus {
  EngineRecordingStatus({
    required this.phase,
    required this.elapsedMs,
    required this.segmentIndex,
    required this.bytesWritten,
    required this.droppedFrames,
  });

  EngineRecordingPhase phase;
  int elapsedMs;

  /// 1-based part number currently being written.
  int segmentIndex;
  int bytesWritten;
  int droppedFrames;
}

class EngineRecordingResult {
  EngineRecordingResult({
    required this.sessionDirectory,
    required this.files,
    required this.durationMs,
    required this.bytesWritten,
  });

  String sessionDirectory;
  List<String> files;
  int durationMs;
  int bytesWritten;
}

/// Peak level since the previous event, 0 (silent) to 1 (full scale).
class EngineAudioLevels {
  EngineAudioLevels({required this.system, required this.microphone});

  double system;
  double microphone;
}

class EngineError {
  EngineError({
    required this.code,
    required this.message,
    required this.isFatal,
  });

  String code;
  String message;

  /// True when recording stopped because of this error.
  bool isFatal;
}

/// Errors use PlatformException codes: `invalid_path`, `permission_denied`,
/// `display_not_found`, `already_recording`, `not_recording`, `unsupported`,
/// `capture_failed`, `writer_failed`.
@HostApi()
abstract class EngineHostApi {
  EngineCapabilities getCapabilities();

  DiskSpace getDiskSpace(String path);

  bool hasScreenCapturePermission();

  /// Shows the system prompt the first time; afterwards only Settings can grant it.
  bool requestScreenCapturePermission();

  void openScreenCaptureSettings();

  bool hasMicrophonePermission();

  /// Shows the system prompt the first time; afterwards only Settings can grant it.
  @async
  bool requestMicrophonePermission();

  void openMicrophoneSettings();

  @async
  List<EngineDisplay> listDisplays();

  @async
  EngineRecordingSession startRecording(EngineRecordingRequest request);

  /// Keeps capturing but stops writing; paused time is not part of the video.
  void pauseRecording();

  void resumeRecording();

  @async
  EngineRecordingResult stopRecording();

  /// Finds unfinished recordings in [outputDirectory], keeps every playable
  /// part and marks the session as recovered. Skips the active recording.
  @async
  List<EngineRecoveredSession> recoverSessions(String outputDirectory);

  void revealInFileManager(String path);

  /// Shows a drag-to-select overlay on the display. Null when the user cancels.
  @async
  EngineCaptureArea? selectArea(int displayId);
}

/// Pushed from native on the platform thread: status about once per second.
@FlutterApi()
abstract class EngineEventsApi {
  void onStatus(EngineRecordingStatus status);

  void onError(EngineError error);

  /// About 15 times per second while recording with audio.
  void onAudioLevels(EngineAudioLevels levels);
}
