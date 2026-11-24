// Renders RecLite's main screens with real fonts for design review.
//
//   flutter test --update-goldens tool/screenshots/screens_test.dart
//
// PNGs go to build/screenshots (or $SHOTS_DIR). Not part of `flutter test`.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/app.dart';
import 'package:reclite/app/di.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';
import 'package:reclite/features/help/domain/repositories/links_repository.dart';
import 'package:reclite/features/help/presentation/bloc/help_cubit.dart';
import 'package:reclite/features/history/domain/entities/saved_recording.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';
import 'package:reclite/features/recording/domain/entities/audio_levels.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/domain/repositories/settings_repository.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/domain/repositories/shortcuts_repository.dart';
import 'package:reclite/features/shortcuts/presentation/bloc/shortcuts_cubit.dart';

import '../../test/fixtures.dart';

const _systemFont = '/System/Library/Fonts/SFNS.ttf';
const _windowsFont = r'C:\Windows\Fonts\SegUIVar.ttf';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  final text = [
    _windowsFont,
    _systemFont,
  ].map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (text == null) return;
  final bytes = ByteData.sublistView(text.readAsBytesSync());
  for (final family in [
    'Segoe UI Variable Text',
    'Segoe UI',
    '.AppleSystemUIFont',
    'Roboto',
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(bytes));
    await loader.load();
  }
}

class _Engine implements EngineRepository {
  @override
  Future<EngineInfo> getEngineInfo() async => testEngineInfo;

  @override
  Future<StorageInfo> getStorageInfo(String folder) async => StorageInfo(
    path: folder,
    freeBytes: 182e9 ~/ 1,
    totalBytes: 500e9 ~/ 1,
  );
}

class _Settings implements SettingsRepository {
  _Settings(this.themeMode);

  @override
  String outputFolder = r'C:\Users\you\Videos\RecLite';

  @override
  String get defaultOutputFolder => outputFolder;

  @override
  Future<void> setOutputFolder(String folder) async => outputFolder = folder;

  @override
  Future<String?> pickFolder({required String initialDirectory}) async => null;

  @override
  RecordingOptions recordingOptions = const RecordingOptions();

  @override
  Future<void> setRecordingOptions(RecordingOptions options) async =>
      recordingOptions = options;

  @override
  bool miniBarWhileRecording = false;

  @override
  Future<void> setMiniBarWhileRecording({required bool enabled}) async =>
      miniBarWhileRecording = enabled;

  @override
  AppThemeMode themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async => themeMode = mode;
}

class _Links implements LinksRepository {
  @override
  Future<void> open(Uri link) async {}

  @override
  String get systemDescription => 'Windows 10.0.26200';
}

class _Desktop implements DesktopRepository {
  @override
  Stream<TrayCommand> get trayCommands => const Stream.empty();

  @override
  Future<void> setTrayStatus(TrayStatus status) async {}

  @override
  Future<void> setMiniWindow({required bool mini}) async {}

  @override
  Future<void> startWindowDrag() async {}
}

class _Shortcuts implements ShortcutsRepository {
  @override
  Stream<ShortcutAction> get pressed => const Stream.empty();

  @override
  bool enabled = true;

  @override
  Future<void> setEnabled({required bool enabled}) async =>
      this.enabled = enabled;

  @override
  Future<Set<ShortcutAction>> register(
    Map<ShortcutAction, KeyCombo> shortcuts,
  ) async => const {};
}

class _History implements HistoryRepository {
  @override
  Future<List<SavedRecording>> list(String folder) async => [
    SavedRecording(
      manifestPath: 'a',
      startedAt: DateTime(2026, 11, 24, 14, 32),
      duration: const Duration(minutes: 47, seconds: 12),
      bytes: 2140000000,
      files: const ['a1.mp4', 'a2.mp4', 'a3.mp4', 'a4.mp4'],
      sourceName: 'Built-in display',
      outcome: RecordingOutcome.completed,
    ),
    SavedRecording(
      manifestPath: 'b',
      startedAt: DateTime(2026, 11, 23, 9, 5),
      duration: const Duration(minutes: 12, seconds: 40),
      bytes: 610000000,
      files: const ['b1.mp4'],
      sourceName: 'Quarterly review - Slides',
      outcome: RecordingOutcome.recovered,
    ),
    SavedRecording(
      manifestPath: 'c',
      startedAt: DateTime(2026, 11, 21, 17, 48),
      duration: const Duration(minutes: 3, seconds: 5),
      bytes: 98000000,
      files: const ['c1.mp4'],
      sourceName: 'Area 1280 × 720',
      outcome: RecordingOutcome.completed,
    ),
    SavedRecording(
      manifestPath: 'd',
      startedAt: DateTime(2026, 11, 20, 11, 2),
      duration: const Duration(minutes: 1, seconds: 51),
      bytes: 51000000,
      files: const ['d1.mp4'],
      sourceName: 'Built-in display',
      outcome: RecordingOutcome.interrupted,
    ),
  ];

  @override
  Future<void> play(String file) async {}

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> moveToTrash(SavedRecording recording) async {}
}

late FakeRecorderRepository _recorder;

void _register(AppThemeMode mode) {
  _recorder = FakeRecorderRepository()..stopResult = testMultiPartResult;
  final settings = _Settings(mode);
  getIt
    ..registerFactory<ReadinessCubit>(
      () => ReadinessCubit(_Engine(), outputFolder: settings.outputFolder),
    )
    ..registerFactory<SourcesCubit>(() => SourcesCubit(_recorder))
    ..registerFactory<AudioCubit>(() => AudioCubit(_recorder))
    ..registerFactory<AudioLevelsCubit>(() => AudioLevelsCubit(_recorder))
    ..registerFactory<RecordingBloc>(() => RecordingBloc(_recorder))
    ..registerFactory<RecoveryCubit>(() => RecoveryCubit(_recorder))
    ..registerFactory<SettingsCubit>(() => SettingsCubit(settings))
    ..registerFactory<ShortcutsCubit>(() => ShortcutsCubit(_Shortcuts()))
    ..registerFactory<WindowModeCubit>(() => WindowModeCubit(_Desktop()))
    ..registerFactory<HelpCubit>(() => HelpCubit(_Links()))
    ..registerFactory<HistoryCubit>(
      () => HistoryCubit(_History(), settings.outputFolder),
    );
}

String get _outDir =>
    Platform.environment['SHOTS_DIR'] ??
    '${Directory.current.path}/build/screenshots';

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(RecLiteApp),
    matchesGoldenFile(Uri.file('$_outDir/$name.png')),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final look in ['windows', 'mac']) {
    for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
      final tag = '${look}_${mode.name}';

      Future<void> pump(WidgetTester tester, Size size) async {
        debugDefaultTargetPlatformOverride = look == 'mac'
            ? TargetPlatform.macOS
            : TargetPlatform.windows;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _register(mode);
        addTearDown(getIt.reset);
        await tester.pumpWidget(const RecLiteApp());
        await tester.pumpAndSettle();
      }

      testWidgets('$tag screens', (tester) async {
        await pump(tester, const Size(1200, 800));
        await _shot(tester, '${tag}_1_record');

        await tester.tap(find.text('Start Recording'));
        await tester.pumpAndSettle();
        _recorder
          ..emitStatus(
            const RecordingStatus(
              phase: RecordingPhase.recording,
              elapsed: Duration(minutes: 17, seconds: 4),
              segmentIndex: 2,
              bytesWritten: 812000000,
              droppedFrames: 0,
            ),
          )
          ..emitLevels(const AudioLevels(system: 0.62, microphone: 0.81));
        await _shot(tester, '${tag}_2_recording');

        await tester.tap(find.text('Stop'));
        await _shot(tester, '${tag}_3_saved');

        await tester.tap(find.text('History'));
        await _shot(tester, '${tag}_4_history');

        await tester.tap(find.text('Settings'));
        await _shot(tester, '${tag}_5_settings');

        await tester.tap(find.text('Help'));
        await _shot(tester, '${tag}_6_help');
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('$tag minimum window', (tester) async {
        await pump(tester, const Size(760, 560));
        await tester.tap(find.text('Start Recording'));
        await tester.pumpAndSettle();
        _recorder.emitStatus(
          const RecordingStatus(
            phase: RecordingPhase.paused,
            elapsed: Duration(minutes: 3, seconds: 41),
            segmentIndex: 1,
            bytesWritten: 151000000,
            droppedFrames: 0,
          ),
        );
        await tester.tap(find.text('Pause'));
        await _shot(tester, '${tag}_7_minimum');
        await tester.tap(find.byTooltip('History'));
        await _shot(tester, '${tag}_8_history_narrow');
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
