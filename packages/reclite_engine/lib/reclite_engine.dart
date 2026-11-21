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
        EngineShortcut,
        EngineTrayCommand,
        EngineTrayState,
        EngineWindow,
        HostPlatform;

/// Single entry point to the native engine. Create one per app.
class RecliteEngine {
  RecliteEngine({EngineHostApi? hostApi}) : _api = hostApi ?? EngineHostApi() {
    EngineEventsApi.setUp(
      _EventSink(_status, _errors, _levels, _shortcuts, _tray),
    );
  }

  final EngineHostApi _api;
  final _status = StreamController<EngineRecordingStatus>.broadcast();
  final _errors = StreamController<EngineError>.broadcast();
  final _levels = StreamController<EngineAudioLevels>.broadcast();
  final _shortcuts = StreamController<int>.broadcast();
  final _tray = StreamController<EngineTrayCommand>.broadcast();

  Stream<EngineRecordingStatus> get status => _status.stream;

  Stream<EngineError> get errors => _errors.stream;

  /// About 15 per second while recording with audio; a final zero event on stop.
  Stream<EngineAudioLevels> get audioLevels => _levels.stream;

  /// Index (in the last [setGlobalShortcuts] list) of a pressed shortcut.
  Stream<int> get shortcutPresses => _shortcuts.stream;

  /// Menu items chosen in the tray (Windows) / menu bar (macOS).
  Stream<EngineTrayCommand> get trayCommands => _tray.stream;

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

  /// Open app windows that can be recorded, excluding RecLite's own.
  Future<List<EngineWindow>> listWindows() => _api.listWindows();

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

  Future<void> openPath(String path) => _api.openPath(path);

  /// https:, http: or mailto: only.
  Future<void> openUrl(String url) => _api.openUrl(url);

  /// Recycle Bin on Windows, Trash on macOS; the user can restore it.
  Future<void> moveToTrash(String path) => _api.moveToTrash(path);

  /// Replaces all system-wide shortcuts; returns the indexes another app uses.
  Future<List<int>> setGlobalShortcuts(List<EngineShortcut> shortcuts) =>
      _api.setGlobalShortcuts(shortcuts);

  /// Small always-on-top bar (true) or the normal window (false).
  Future<void> setMiniWindow(bool mini) => _api.setMiniWindow(mini);

  /// Moves the window with the mouse; call on pointer down.
  Future<void> startWindowDrag() => _api.startWindowDrag();

  Future<void> setTrayState(EngineTrayState state) => _api.setTrayState(state);

  /// Drag-to-select overlay on [displayId]; null when the user cancels.
  Future<EngineCaptureArea?> selectArea(int displayId) =>
      _api.selectArea(displayId);

  void dispose() {
    EngineEventsApi.setUp(null);
    unawaited(_status.close());
    unawaited(_errors.close());
    unawaited(_levels.close());
    unawaited(_shortcuts.close());
    unawaited(_tray.close());
  }
}

class _EventSink implements EngineEventsApi {
  _EventSink(
    this._status,
    this._errors,
    this._levels,
    this._shortcuts,
    this._tray,
  );

  final StreamController<EngineRecordingStatus> _status;
  final StreamController<EngineError> _errors;
  final StreamController<EngineAudioLevels> _levels;
  final StreamController<int> _shortcuts;
  final StreamController<EngineTrayCommand> _tray;

  @override
  void onAudioLevels(EngineAudioLevels levels) => _levels.add(levels);

  @override
  void onStatus(EngineRecordingStatus status) => _status.add(status);

  @override
  void onError(EngineError error) => _errors.add(error);

  @override
  void onShortcut(int index) => _shortcuts.add(index);

  @override
  void onTrayCommand(EngineTrayCommand command) => _tray.add(command);
}
