import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);

  static const _outputFolderKey = 'output_folder';
  static const _segmentMinutesKey = 'segment_minutes';
  static const _framesPerSecondKey = 'frames_per_second';
  static const _maxHeightKey = 'max_height';
  static const _showCursorKey = 'show_cursor';
  static const _themeModeKey = 'theme_mode';
  static const _miniBarKey = 'mini_bar_while_recording';

  final SharedPreferences _prefs;

  @override
  String get defaultOutputFolder => RecordingDefaults.outputFolder();

  @override
  String get outputFolder =>
      _prefs.getString(_outputFolderKey) ?? defaultOutputFolder;

  @override
  Future<void> setOutputFolder(String folder) async {
    try {
      await Directory(folder).create(recursive: true);
    } on FileSystemException {
      throw const StorageFailure(
        'RecLite cannot save to this folder. Choose another one.',
      );
    }
    if (folder == defaultOutputFolder) {
      await _prefs.remove(_outputFolderKey);
    } else {
      await _prefs.setString(_outputFolderKey, folder);
    }
  }

  @override
  Future<String?> pickFolder({required String initialDirectory}) {
    return getDirectoryPath(
      initialDirectory: Directory(initialDirectory).existsSync()
          ? initialDirectory
          : null,
      confirmButtonText: 'Use this folder',
    );
  }

  @override
  RecordingOptions get recordingOptions {
    const fallback = RecordingOptions();
    final minutes = _choice(
      _segmentMinutesKey,
      RecordingDefaults.segmentMinuteChoices,
      fallback.segmentDuration.inMinutes,
    );
    return RecordingOptions(
      segmentDuration:
          RecordingDefaults.debugSegmentOverride ?? Duration(minutes: minutes),
      framesPerSecond: _choice(
        _framesPerSecondKey,
        RecordingDefaults.framesPerSecondChoices,
        fallback.framesPerSecond,
      ),
      maxHeight: _choice(
        _maxHeightKey,
        RecordingDefaults.maxHeightChoices,
        fallback.maxHeight,
      ),
      showCursor: _prefs.getBool(_showCursorKey) ?? fallback.showCursor,
    );
  }

  @override
  Future<void> setRecordingOptions(RecordingOptions options) async {
    final minutes = options.segmentDuration.inMinutes;
    await (
      // A debug override in seconds is never saved as the user's choice.
      RecordingDefaults.segmentMinuteChoices.contains(minutes)
          ? _prefs.setInt(_segmentMinutesKey, minutes)
          : Future.value(true),
      _prefs.setInt(_framesPerSecondKey, options.framesPerSecond),
      _prefs.setInt(_maxHeightKey, options.maxHeight),
      _prefs.setBool(_showCursorKey, options.showCursor),
    ).wait;
  }

  @override
  bool get miniBarWhileRecording => _prefs.getBool(_miniBarKey) ?? true;

  @override
  Future<void> setMiniBarWhileRecording({required bool enabled}) =>
      _prefs.setBool(_miniBarKey, enabled);

  @override
  AppThemeMode get themeMode => AppThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_themeModeKey),
    orElse: () => AppThemeMode.system,
  );

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  /// A stored value outside [choices] (e.g. from an older version) falls back.
  int _choice(String key, List<int> choices, int fallback) {
    final value = _prefs.getInt(key);
    return value != null && choices.contains(value) ? value : fallback;
  }
}
