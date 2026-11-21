import 'package:reclite/features/history/domain/entities/saved_recording.dart';

/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class HistoryRepository {
  /// Newest first. Skips a recording that is still running.
  Future<List<SavedRecording>> list(String folder);

  /// Opens the file in the default video player.
  Future<void> play(String file);

  Future<void> reveal(String path);

  /// Its videos go to the Recycle Bin (Windows) / Trash (macOS).
  Future<void> moveToTrash(SavedRecording recording);
}
