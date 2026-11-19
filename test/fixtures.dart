import 'dart:async';

import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

const testEngineInfo = EngineInfo(
  platformName: 'macOS',
  osVersion: '15.1.0',
  minimumOsVersion: '13.0',
  meetsMinimumOs: true,
  supportsRecording: true,
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
        supportsRecording: supportsRecording,
        supportsSystemAudio: supportsSystemAudio,
        supportsMicrophoneViaScreenCapture: supportsMicrophoneViaScreenCapture,
        hasHardwareH264Encoder:
            hasHardwareH264Encoder ?? this.hasHardwareH264Encoder,
        hasHardwareHevcEncoder: hasHardwareHevcEncoder,
        engineVersion: engineVersion,
      );
}

const testDisplays = [
  CaptureDisplay(
    id: 2,
    name: 'Studio Display',
    width: 5120,
    height: 2880,
    isMain: false,
  ),
  CaptureDisplay(
    id: 1,
    name: 'Built-in Retina Display',
    width: 3024,
    height: 1964,
    isMain: true,
  ),
];

const testArea = CaptureArea(x: 100, y: 80, width: 1280, height: 720);

const testConfig = RecordingConfig(
  displayId: 1,
  outputFolder: '/rec',
  framesPerSecond: 30,
  maxHeight: 1440,
);

const testResult = RecordingResult(
  sessionDirectory: '/rec/RecLite_2026-11-19_10-00-00',
  files: [
    '/rec/RecLite_2026-11-19_10-00-00/RecLite_2026-11-19_10-00-00_Part01.mp4',
  ],
  duration: Duration(seconds: 65),
  bytesWritten: 42000000,
);

RecordingStatus testStatus(int seconds) => RecordingStatus(
  phase: RecordingPhase.recording,
  elapsed: Duration(seconds: seconds),
  segmentIndex: 1,
  bytesWritten: seconds * 1000000,
  droppedFrames: 0,
);

/// In-memory recorder for widget tests; push engine events with [emitStatus].
class FakeRecorderRepository implements RecorderRepository {
  FakeRecorderRepository({this.permission = true});

  bool permission;
  bool microphonePermission = true;

  /// What the drag-to-select overlay returns; null simulates Esc.
  CaptureArea? areaToSelect = testArea;
  final startCalls = <RecordingConfig>[];
  final _status = StreamController<RecordingStatus>.broadcast();
  final _interruptions = StreamController<RecordingInterruption>.broadcast();
  final _levels = StreamController<AudioLevels>.broadcast();

  void emitLevels(AudioLevels l) => _levels.add(l);

  void emitStatus(RecordingStatus s) => _status.add(s);

  Future<void> dispose() async {
    await _status.close();
    await _interruptions.close();
    await _levels.close();
  }

  @override
  Stream<RecordingStatus> get status => _status.stream;

  @override
  Stream<RecordingInterruption> get interruptions => _interruptions.stream;

  @override
  Stream<AudioLevels> get audioLevels => _levels.stream;

  @override
  Future<bool> hasMicrophonePermission() async => microphonePermission;

  @override
  Future<bool> requestMicrophonePermission() async => microphonePermission;

  @override
  Future<void> openMicrophoneSettings() async {}

  @override
  Future<bool> hasScreenPermission() async => permission;

  @override
  Future<bool> requestScreenPermission() async => permission;

  @override
  Future<void> openScreenPermissionSettings() async {}

  @override
  Future<List<CaptureDisplay>> listDisplays() async => testDisplays;

  @override
  Future<void> start(RecordingConfig config) async => startCalls.add(config);

  @override
  Future<RecordingResult> stop() async => testResult;

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<CaptureArea?> selectArea(int displayId) async => areaToSelect;
}
