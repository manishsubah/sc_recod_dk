part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.outputFolder,
    required this.defaultOutputFolder,
    this.options = const RecordingOptions(),
    this.themeMode = AppThemeMode.system,
    this.miniBarWhileRecording = true,
    this.error,
  });

  final String outputFolder;
  final String defaultOutputFolder;
  final RecordingOptions options;
  final AppThemeMode themeMode;
  final bool miniBarWhileRecording;

  /// Shown once, then cleared by the next state.
  final String? error;

  bool get usesDefaultFolder => outputFolder == defaultOutputFolder;

  SettingsState copyWith({
    String? outputFolder,
    RecordingOptions? options,
    AppThemeMode? themeMode,
    bool? miniBarWhileRecording,
    String? error,
  }) => SettingsState(
    outputFolder: outputFolder ?? this.outputFolder,
    defaultOutputFolder: defaultOutputFolder,
    options: options ?? this.options,
    themeMode: themeMode ?? this.themeMode,
    miniBarWhileRecording: miniBarWhileRecording ?? this.miniBarWhileRecording,
    error: error,
  );

  @override
  List<Object?> get props => [
    outputFolder,
    defaultOutputFolder,
    options,
    themeMode,
    miniBarWhileRecording,
    error,
  ];
}
