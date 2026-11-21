import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';

/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class SettingsRepository {
  /// Parent folder for recordings; each recording gets its own folder inside.
  String get outputFolder;

  String get defaultOutputFolder;

  /// Creates the folder if needed and remembers it.
  Future<void> setOutputFolder(String folder);

  /// Shows the system folder picker. Null when the user cancels.
  Future<String?> pickFolder({required String initialDirectory});

  RecordingOptions get recordingOptions;

  Future<void> setRecordingOptions(RecordingOptions options);

  /// Shrink the window to a small bar while recording.
  bool get miniBarWhileRecording;

  Future<void> setMiniBarWhileRecording({required bool enabled});

  AppThemeMode get themeMode;

  Future<void> setThemeMode(AppThemeMode mode);
}
