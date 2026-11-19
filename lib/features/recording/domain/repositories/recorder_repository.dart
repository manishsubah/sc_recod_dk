import 'package:reclite/features/recording/domain/entities/capture_area.dart';
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
import 'package:reclite/features/recording/domain/entities/recording_config.dart';
import 'package:reclite/features/recording/domain/entities/recording_interruption.dart';
import 'package:reclite/features/recording/domain/entities/recording_result.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';

/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class RecorderRepository {
  Stream<RecordingStatus> get status;

  Stream<RecordingInterruption> get interruptions;

  Future<bool> hasScreenPermission();

  /// Shows the system prompt only the first time it is called.
  Future<bool> requestScreenPermission();

  Future<void> openScreenPermissionSettings();

  Future<List<CaptureDisplay>> listDisplays();

  Future<void> start(RecordingConfig config);

  Future<RecordingResult> stop();

  Future<void> reveal(String path);

  /// Lets the user drag out an area on [displayId]. Null when cancelled.
  Future<CaptureArea?> selectArea(int displayId);
}
