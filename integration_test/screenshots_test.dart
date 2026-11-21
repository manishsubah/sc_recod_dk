// Renders the app in light mode with demo data and saves the README screenshots
// to docs/screenshots/. Run on a desktop:
//
//   flutter test integration_test/screenshots_test.dart -d windows
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
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

import '../test/fixtures.dart';

const _folder = r'C:\Users\Alex\Videos\RecLite';
const _windowSize = Size(1100, 760);

class _DemoRecorder extends FakeRecorderRepository {
  @override
  Future<List<CaptureDisplay>> listDisplays() async => const [
    CaptureDisplay(
      id: 1,
      name: 'Built-in Display',
      width: 1920,
      height: 1080,
      isMain: true,
    ),
    CaptureDisplay(
      id: 2,
      name: 'DELL U2723QE',
      width: 3840,
      height: 2160,
      isMain: false,
    ),
  ];
}

class _DemoEngine implements EngineRepository {
  @override
  Future<EngineInfo> getEngineInfo() async => const EngineInfo(
    platformName: 'Windows',
    osVersion: '10.0.26200',
    minimumOsVersion: '10.0.19041',
    meetsMinimumOs: true,
    supportsRecording: true,
    supportsSystemAudio: true,
    supportsMicrophoneViaScreenCapture: true,
    hasHardwareH264Encoder: true,
    hasHardwareHevcEncoder: true,
    engineVersion: '0.1.0',
  );

  @override
  Future<StorageInfo> getStorageInfo(String folder) async =>
      StorageInfo(path: folder, freeBytes: 412e9 ~/ 1, totalBytes: 1e12 ~/ 1);
}

class _DemoSettings implements SettingsRepository {
  @override
  String get outputFolder => _folder;

  @override
  String get defaultOutputFolder => _folder;

  @override
  Future<void> setOutputFolder(String folder) async {}

  @override
  Future<String?> pickFolder({required String initialDirectory}) async => null;

  @override
  RecordingOptions get recordingOptions =>
      const RecordingOptions(maxHeight: 1080);

  @override
  Future<void> setRecordingOptions(RecordingOptions options) async {}

  @override
  bool get miniBarWhileRecording => false;

  @override
  Future<void> setMiniBarWhileRecording({required bool enabled}) async {}

  @override
  AppThemeMode get themeMode => AppThemeMode.light;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}
}

class _DemoHistory implements HistoryRepository {
  static SavedRecording _recording(
    DateTime at,
    Duration length,
    int megabytes, {
    int parts = 1,
    String source = 'Built-in Display',
    RecordingOutcome outcome = RecordingOutcome.completed,
  }) {
    final stamp =
        '${at.year}-${_two(at.month)}-${_two(at.day)}_'
        '${_two(at.hour)}-${_two(at.minute)}-00';
    return SavedRecording(
      manifestPath: 'RecLite_$stamp.json',
      startedAt: at,
      duration: length,
      bytes: megabytes * 1000 * 1000,
      files: [
        if (parts == 1)
          '$_folder\\RecLite_$stamp.mp4'
        else
          for (var i = 1; i <= parts; i++)
            '$_folder\\RecLite_${stamp}_Part0$i.mp4',
      ],
      sourceName: source,
      outcome: outcome,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Future<List<SavedRecording>> list(String folder) async => [
    _recording(
      DateTime(2026, 11, 21, 16, 42),
      const Duration(minutes: 8, seconds: 14),
      312,
    ),
    _recording(
      DateTime(2026, 11, 21, 11, 5),
      const Duration(minutes: 47, seconds: 30),
      1840,
      parts: 4,
      source: 'Quarterly review - Slides',
    ),
    _recording(
      DateTime(2026, 11, 20, 18, 20),
      const Duration(minutes: 3, seconds: 2),
      96,
      source: 'DELL U2723QE',
    ),
    _recording(
      DateTime(2026, 11, 19, 9, 30),
      const Duration(minutes: 22, seconds: 41),
      870,
      parts: 2,
      outcome: RecordingOutcome.recovered,
    ),
  ];

  @override
  Future<void> play(String file) async {}

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> moveToTrash(SavedRecording recording) async {}
}

class _DemoShortcuts implements ShortcutsRepository {
  @override
  Stream<ShortcutAction> get pressed => const Stream.empty();

  @override
  bool get enabled => true;

  @override
  Future<void> setEnabled({required bool enabled}) async {}

  @override
  Future<Set<ShortcutAction>> register(
    Map<ShortcutAction, KeyCombo> shortcuts,
  ) async => const {};
}

class _DemoDesktop implements DesktopRepository {
  @override
  Stream<TrayCommand> get trayCommands => const Stream.empty();

  @override
  Future<void> setTrayStatus(TrayStatus status) async {}

  @override
  Future<void> setMiniWindow({required bool mini}) async {}

  @override
  Future<void> startWindowDrag() async {}
}

class _DemoLinks implements LinksRepository {
  @override
  Future<void> open(Uri link) async {}

  @override
  String get systemDescription => 'Windows 10.0.26200';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final shots = Directory('docs/screenshots')..createSync(recursive: true);
  final frame = GlobalKey();

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary =
        frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${shots.path}${Platform.pathSeparator}$name.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('README screenshots (light mode)', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = _windowSize * dpr;
    addTearDown(tester.view.resetPhysicalSize);

    final recorder = _DemoRecorder();
    getIt
      ..registerFactory<SettingsCubit>(() => SettingsCubit(_DemoSettings()))
      ..registerFactory<ReadinessCubit>(
        () => ReadinessCubit(
          _DemoEngine(),
          outputFolder: _folder,
          options: const RecordingOptions(maxHeight: 1080),
        ),
      )
      ..registerFactory<SourcesCubit>(() => SourcesCubit(recorder))
      ..registerFactory<AudioCubit>(() => AudioCubit(recorder))
      ..registerFactory<AudioLevelsCubit>(() => AudioLevelsCubit(recorder))
      ..registerFactory<RecordingBloc>(() => RecordingBloc(recorder))
      ..registerFactory<RecoveryCubit>(() => RecoveryCubit(recorder))
      ..registerFactory<HistoryCubit>(
        () => HistoryCubit(_DemoHistory(), _folder),
      )
      ..registerFactory<ShortcutsCubit>(() => ShortcutsCubit(_DemoShortcuts()))
      ..registerFactory<WindowModeCubit>(() => WindowModeCubit(_DemoDesktop()))
      ..registerFactory<HelpCubit>(() => HelpCubit(_DemoLinks()));

    await tester.pumpWidget(
      RepaintBoundary(key: frame, child: const RecLiteApp()),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'record');

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    recorder
      ..emitStatus(
        const RecordingStatus(
          phase: RecordingPhase.recording,
          elapsed: Duration(minutes: 12, seconds: 47),
          segmentIndex: 1,
          bytesWritten: 486 * 1000 * 1000,
          droppedFrames: 0,
        ),
      )
      ..emitLevels(const AudioLevels(system: 0.62, microphone: 0.35));
    await capture(tester, 'recording');
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recording'));

    await tester.tap(find.text('History'));
    await capture(tester, 'history');

    await tester.tap(find.text('Settings'));
    await capture(tester, 'settings');

    await tester.tap(find.text('Help'));
    await capture(tester, 'help');

    await getIt.reset();
    await recorder.dispose();
  });
}
