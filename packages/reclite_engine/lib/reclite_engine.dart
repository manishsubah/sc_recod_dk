library;

import 'dart:async';

import 'src/messages.g.dart';

export 'src/messages.g.dart'
    show
        DiskSpace,
        EngineCaptureArea,
        EngineCapabilities,
        EngineDisplay,
        EngineError,
        EngineRecordingPhase,
        EngineRecordingRequest,
        EngineRecordingResult,
        EngineRecordingSession,
        EngineRecordingStatus,
        HostPlatform;

/// Single entry point to the native engine. Create one per app.
class RecliteEngine {
  RecliteEngine({EngineHostApi? hostApi}) : _api = hostApi ?? EngineHostApi() {
    EngineEventsApi.setUp(_EventSink(_status, _errors));
  }

  final EngineHostApi _api;
  final _status = StreamController<EngineRecordingStatus>.broadcast();
  final _errors = StreamController<EngineError>.broadcast();

  Stream<EngineRecordingStatus> get status => _status.stream;

  Stream<EngineError> get errors => _errors.stream;

  Future<EngineCapabilities> getCapabilities() => _api.getCapabilities();

  Future<DiskSpace> getDiskSpace(String path) => _api.getDiskSpace(path);

  Future<bool> hasScreenCapturePermission() =>
      _api.hasScreenCapturePermission();

  Future<bool> requestScreenCapturePermission() =>
      _api.requestScreenCapturePermission();

  Future<void> openScreenCaptureSettings() => _api.openScreenCaptureSettings();

  Future<List<EngineDisplay>> listDisplays() => _api.listDisplays();

  Future<EngineRecordingSession> startRecording(
    EngineRecordingRequest request,
  ) => _api.startRecording(request);

  Future<EngineRecordingResult> stopRecording() => _api.stopRecording();

  Future<void> revealInFileManager(String path) =>
      _api.revealInFileManager(path);

  /// Drag-to-select overlay on [displayId]; null when the user cancels.
  Future<EngineCaptureArea?> selectArea(int displayId) =>
      _api.selectArea(displayId);

  void dispose() {
    EngineEventsApi.setUp(null);
    unawaited(_status.close());
    unawaited(_errors.close());
  }
}

class _EventSink implements EngineEventsApi {
  _EventSink(this._status, this._errors);

  final StreamController<EngineRecordingStatus> _status;
  final StreamController<EngineError> _errors;

  @override
  void onStatus(EngineRecordingStatus status) => _status.add(status);

  @override
  void onError(EngineError error) => _errors.add(error);
}
