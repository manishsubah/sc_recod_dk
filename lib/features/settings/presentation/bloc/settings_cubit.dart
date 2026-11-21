import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/domain/repositories/settings_repository.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._settings)
    : super(
        SettingsState(
          outputFolder: _settings.outputFolder,
          defaultOutputFolder: _settings.defaultOutputFolder,
          options: _settings.recordingOptions,
          themeMode: _settings.themeMode,
          miniBarWhileRecording: _settings.miniBarWhileRecording,
        ),
      );

  final SettingsRepository _settings;

  Future<void> chooseFolder() async {
    final String? picked;
    try {
      picked = await _settings.pickFolder(initialDirectory: state.outputFolder);
    } on Object {
      _showError('The folder picker could not be opened.');
      return;
    }
    if (picked == null || picked == state.outputFolder) return;
    await _applyFolder(picked);
  }

  Future<void> useDefaultFolder() => _applyFolder(state.defaultOutputFolder);

  Future<void> setSegmentMinutes(int minutes) => _applyOptions(
    state.options.copyWith(segmentDuration: Duration(minutes: minutes)),
  );

  Future<void> setMaxHeight(int height) =>
      _applyOptions(state.options.copyWith(maxHeight: height));

  Future<void> setFramesPerSecond(int fps) =>
      _applyOptions(state.options.copyWith(framesPerSecond: fps));

  Future<void> setShowCursor({required bool show}) =>
      _applyOptions(state.options.copyWith(showCursor: show));

  Future<void> setMiniBarWhileRecording({required bool enabled}) async {
    emit(state.copyWith(miniBarWhileRecording: enabled));
    await _settings.setMiniBarWhileRecording(enabled: enabled);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    await _settings.setThemeMode(mode);
  }

  Future<void> _applyOptions(RecordingOptions options) async {
    emit(state.copyWith(options: options));
    await _settings.setRecordingOptions(options);
  }

  Future<void> _applyFolder(String folder) async {
    try {
      await _settings.setOutputFolder(folder);
      emit(state.copyWith(outputFolder: folder));
    } on Failure catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    emit(state.copyWith(error: message));
    emit(state.copyWith());
  }
}
