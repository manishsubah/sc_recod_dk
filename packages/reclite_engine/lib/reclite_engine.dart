library;

import 'dart:async';

import 'src/messages.g.dart';

export 'src/messages.g.dart'
    show
        DiskSpace,
        EngineAudioLevels,
        EngineCaptureArea,
        EngineCapabilities,
        EngineDisplay,
        EngineError,
        EngineRecordingPhase,
        EngineRecordingRequest,
        EngineRecordingResult,
        EngineRecordingSession,
        EngineRecordingStatus,
        EngineRecoveredSession,
        HostPlatform;

/// Single entry point to the native engine. Create one per app.
class RecliteEngine {
  RecliteEngine({EngineHostApi? hostApi}) : _api = hostApi ?? EngineHostApi() {
    EngineEventsApi.setUp(_EventSink(_status, _errors, _levels));
  }

  final EngineHostApi _api;
  final _status = StreamController<EngineRecordingStatus>.broadcast();
  final _errors = StreamController<EngineError>.broadcast();
  final _levels = StreamController<EngineAudioLevels>.broadcast();

  Stream<EngineRecordingStatus> get status => _status.stream;

  Stream<EngineError> get errors => _errors.stream;

  /// About 15 per second while recording with audio; a final zero event on stop.
  Stream<EngineAudioLevels> get audioLevels => _levels.stream;

  Future<EngineCapabilities> getCapabilities() => _api.getCapabilities();

  Future<DiskSpace> getDiskSpace(String path) => _api.getDiskSpace(path);

  Future<bool> hasScreenCapturePermission() =>
      _api.hasScreenCapturePermission();

  Future<bool> requestScreenCapturePermission() =>
      _api.requestScreenCapturePermission();

  Future<void> openScreenCaptureSettings() => _api.openScreenCaptureSettings();

  Future<bool> hasMicrophonePermission() => _api.hasMicrophonePermission();

  Future<bool> requestMicrophonePermission() =>
      _api.requestMicrophonePermission();

  Future<void> openMicrophoneSettings() => _api.openMicrophoneSettings();

  Future<List<EngineDisplay>> listDisplays() => _api.listDisplays();

  Future<EngineRecordingSession> startRecording(
    EngineRecordingRequest request,
  ) => _api.startRecording(request);

  Future<void> pauseRecording() => _api.pauseRecording();

  Future<void> resumeRecording() => _api.resumeRecording();

  Future<EngineRecordingResult> stopRecording() => _api.stopRecording();

  /// Repairs recordings interrupted by a crash or power loss in [outputDirectory].
  Future<List<EngineRecoveredSession>> recoverSessions(
    String outputDirectory,
  ) => _api.recoverSessions(outputDirectory);

  Future<void> revealInFileManager(String path) =>
      _api.revealInFileManager(path);

  /// Drag-to-select overlay on [displayId]; null when the user cancels.
  Future<EngineCaptureArea?> selectArea(int displayId) =>
      _api.selectArea(displayId);

  void dispose() {
    EngineEventsApi.setUp(null);
    unawaited(_status.close());
    unawaited(_errors.close());
    unawaited(_levels.close());
  }
}

class _EventSink implements EngineEventsApi {
  _EventSink(this._status, this._errors, this._levels);

  final StreamController<EngineRecordingStatus> _status;
  final StreamController<EngineError> _errors;
  final StreamController<EngineAudioLevels> _levels;

  @override
  void onAudioLevels(EngineAudioLevels levels) => _levels.add(levels);

  @override
  void onStatus(EngineRecordingStatus status) => _status.add(status);

  @override
  void onError(EngineError error) => _errors.add(error);
}
