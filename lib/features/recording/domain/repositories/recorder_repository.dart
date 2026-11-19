import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/entities/recovered_recording.dart';

/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class RecorderRepository {
  Stream<RecordingStatus> get status;

  Stream<RecordingInterruption> get interruptions;

  /// About 15 per second while recording with audio; ends with [AudioLevels.silent].
  Stream<AudioLevels> get audioLevels;

  Future<bool> hasScreenPermission();

  /// Shows the system prompt only the first time it is called.
  Future<bool> requestScreenPermission();

  Future<void> openScreenPermissionSettings();

  Future<bool> hasMicrophonePermission();

  /// Shows the system prompt only while the user hasn't answered yet.
  Future<bool> requestMicrophonePermission();

  Future<void> openMicrophoneSettings();

  Future<List<CaptureDisplay>> listDisplays();

  Future<void> start(RecordingConfig config);

  Future<void> pause();

  Future<void> resume();

  Future<RecordingResult> stop();

  /// Repairs recordings in [folder] that were interrupted by a crash or power loss.
  Future<List<RecoveredRecording>> recover(String folder);

  Future<void> reveal(String path);

  /// Lets the user drag out an area on [displayId]. Null when cancelled.
  Future<CaptureArea?> selectArea(int displayId);
}
