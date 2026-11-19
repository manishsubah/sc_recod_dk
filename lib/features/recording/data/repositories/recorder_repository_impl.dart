import 'package:flutter/services.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

class RecorderRepositoryImpl implements RecorderRepository {
  RecorderRepositoryImpl(this._engine);

  final RecliteEngine _engine;

  @override
  Stream<RecordingStatus> get status => _engine.status.map(_toStatus);

  @override
  Stream<RecordingInterruption> get interruptions => _engine.errors.map(
    (e) => RecordingInterruption(message: e.message, isFatal: e.isFatal),
  );

  @override
  Stream<AudioLevels> get audioLevels => _engine.audioLevels.map(
    (l) => AudioLevels(system: l.system, microphone: l.microphone),
  );

  @override
  Future<bool> hasMicrophonePermission() =>
      _guard(_engine.hasMicrophonePermission);

  @override
  Future<bool> requestMicrophonePermission() =>
      _guard(_engine.requestMicrophonePermission);

  @override
  Future<void> openMicrophoneSettings() =>
      _guard(_engine.openMicrophoneSettings);

  @override
  Future<bool> hasScreenPermission() =>
      _guard(_engine.hasScreenCapturePermission);

  @override
  Future<bool> requestScreenPermission() =>
      _guard(_engine.requestScreenCapturePermission);

  @override
  Future<void> openScreenPermissionSettings() =>
      _guard(_engine.openScreenCaptureSettings);

  @override
  Future<List<CaptureDisplay>> listDisplays() => _guard(() async {
    final displays = await _engine.listDisplays();
    return [
      for (final d in displays)
        CaptureDisplay(
          id: d.id,
          name: d.name,
          width: d.width,
          height: d.height,
          isMain: d.isMain,
        ),
    ];
  });

  @override
  Future<void> start(RecordingConfig config) => _guard(
    () => _engine.startRecording(
      EngineRecordingRequest(
        displayId: config.displayId,
        outputDirectory: config.outputFolder,
        framesPerSecond: config.framesPerSecond,
        maxHeight: config.maxHeight,
        captureSystemAudio: config.captureSystemAudio,
        captureMicrophone: config.captureMicrophone,
        area: switch (config.area) {
          final a? => EngineCaptureArea(
            x: a.x,
            y: a.y,
            width: a.width,
            height: a.height,
          ),
          null => null,
        },
      ),
    ),
  );

  @override
  Future<RecordingResult> stop() => _guard(() async {
    final r = await _engine.stopRecording();
    return RecordingResult(
      sessionDirectory: r.sessionDirectory,
      files: r.files,
      duration: Duration(milliseconds: r.durationMs),
      bytesWritten: r.bytesWritten,
    );
  });

  @override
  Future<void> reveal(String path) =>
      _guard(() => _engine.revealInFileManager(path));

  @override
  Future<CaptureArea?> selectArea(int displayId) => _guard(() async {
    final a = await _engine.selectArea(displayId);
    return a == null
        ? null
        : CaptureArea(x: a.x, y: a.y, width: a.width, height: a.height);
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }

  static RecordingStatus _toStatus(EngineRecordingStatus s) => RecordingStatus(
    phase: switch (s.phase) {
      EngineRecordingPhase.idle => RecordingPhase.idle,
      EngineRecordingPhase.starting => RecordingPhase.starting,
      EngineRecordingPhase.recording => RecordingPhase.recording,
      EngineRecordingPhase.stopping => RecordingPhase.stopping,
    },
    elapsed: Duration(milliseconds: s.elapsedMs),
    segmentIndex: s.segmentIndex,
    bytesWritten: s.bytesWritten,
    droppedFrames: s.droppedFrames,
  );
}
