import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/app.dart';
import 'package:reclite/app/di.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';
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

import 'fixtures.dart';

class _FakeEngineRepository implements EngineRepository {
  @override
  Future<EngineInfo> getEngineInfo() async => testEngineInfo;

  @override
  Future<StorageInfo> getStorageInfo(String folder) async =>
      StorageInfo(path: folder, freeBytes: 48e9 ~/ 1, totalBytes: 500e9 ~/ 1);
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  String outputFolder = '/rec';

  @override
  String get defaultOutputFolder => '/rec';

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
  AppThemeMode themeMode = AppThemeMode.system;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async => themeMode = mode;
}

class _FakeDesktopRepository implements DesktopRepository {
  final _commands = StreamController<TrayCommand>.broadcast();
  final miniCalls = <bool>[];
  final trayStatuses = <TrayStatus>[];

  void choose(TrayCommand command) => _commands.add(command);

  Future<void> dispose() => _commands.close();

  @override
  Stream<TrayCommand> get trayCommands => _commands.stream;

  @override
  Future<void> setTrayStatus(TrayStatus status) async =>
      trayStatuses.add(status);

  @override
  Future<void> setMiniWindow({required bool mini}) async => miniCalls.add(mini);

  @override
  Future<void> startWindowDrag() async {}
}

class _FakeShortcutsRepository implements ShortcutsRepository {
  final _presses = StreamController<ShortcutAction>.broadcast();

  void press(ShortcutAction action) => _presses.add(action);

  Future<void> dispose() => _presses.close();

  @override
  Stream<ShortcutAction> get pressed => _presses.stream;

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

class _FakeHistoryRepository implements HistoryRepository {
  @override
  Future<List<SavedRecording>> list(String folder) async => const [];

  @override
  Future<void> play(String file) async {}

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> moveToTrash(String sessionDirectory) async {}
}

void main() {
  late FakeRecorderRepository recorder;
  late _FakeShortcutsRepository shortcuts;
  late _FakeDesktopRepository desktop;
  late _FakeSettingsRepository settings;

  setUp(() {
    recorder = FakeRecorderRepository();
    shortcuts = _FakeShortcutsRepository();
    desktop = _FakeDesktopRepository();
    settings = _FakeSettingsRepository();
    getIt
      ..registerFactory<ReadinessCubit>(
        () => ReadinessCubit(_FakeEngineRepository(), outputFolder: '/rec'),
      )
      ..registerFactory<SourcesCubit>(() => SourcesCubit(recorder))
      ..registerFactory<AudioCubit>(() => AudioCubit(recorder))
      ..registerFactory<AudioLevelsCubit>(() => AudioLevelsCubit(recorder))
      ..registerFactory<RecordingBloc>(() => RecordingBloc(recorder))
      ..registerFactory<RecoveryCubit>(
        () => RecoveryCubit(recorder, outputFolder: '/rec'),
      )
      ..registerFactory<SettingsCubit>(() => SettingsCubit(settings))
      ..registerFactory<ShortcutsCubit>(() => ShortcutsCubit(shortcuts))
      ..registerFactory<WindowModeCubit>(() => WindowModeCubit(desktop))
      ..registerFactory<HistoryCubit>(
        () => HistoryCubit(_FakeHistoryRepository(), '/rec'),
      );
  });

  tearDown(() async {
    await getIt.reset();
    await recorder.dispose();
    await shortcuts.dispose();
    await desktop.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shows readiness and navigates between sections', (tester) async {
    await pumpApp(tester);

    expect(find.text('Ready to Record'), findsOneWidget);
    expect(find.text('macOS 15.1.0'), findsOneWidget);
    expect(find.text('H.264 · HEVC'), findsOneWidget);
    expect(find.text('48.0 GB · about 40 h'), findsOneWidget);
    expect(
      find.text('Built-in Retina Display (3024 × 1964) · Main'),
      findsOneWidget,
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No recordings yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Save recordings to'), findsOneWidget);
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('1440p'), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('/rec'), findsOneWidget);
  });

  testWidgets('start → live timer → stop → saved', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    expect(recorder.startCalls.single.displayId, 1);
    expect(recorder.startCalls.single.outputFolder, '/rec');
    expect(find.text('REC'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    recorder.emitStatus(testStatus(65));
    await tester.pumpAndSettle();
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Part 1 · 65.0 MB'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Recording saved'), findsOneWidget);
    expect(find.text('RecLite_2026-11-19_10-00-00_Part01.mp4'), findsOneWidget);

    await tester.tap(find.text('New recording'));
    await tester.pumpAndSettle();
    expect(find.text('Start Recording'), findsOneWidget);
  });

  testWidgets('global shortcuts start, pause and stop a recording', (
    tester,
  ) async {
    await pumpApp(tester);

    shortcuts.press(ShortcutAction.pauseResume);
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 0, reason: 'nothing to pause yet');

    shortcuts.press(ShortcutAction.startStop);
    await tester.pumpAndSettle();
    expect(recorder.startCalls.single.outputFolder, '/rec');
    expect(find.text('REC'), findsOneWidget);

    shortcuts.press(ShortcutAction.pauseResume);
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 1);
    expect(find.text('PAUSED'), findsOneWidget);

    shortcuts.press(ShortcutAction.pauseResume);
    await tester.pumpAndSettle();
    expect(recorder.resumeCalls, 1);

    shortcuts.press(ShortcutAction.startStop);
    await tester.pumpAndSettle();
    expect(find.text('Recording saved'), findsOneWidget);

    shortcuts.press(ShortcutAction.startStop);
    await tester.pumpAndSettle();
    expect(
      recorder.startCalls,
      hasLength(2),
      reason: 'starts again after a save',
    );
  });

  testWidgets('mini bar while recording, tray controls, back to full', (
    tester,
  ) async {
    settings.miniBarWhileRecording = true;
    await pumpApp(tester);
    expect(desktop.trayStatuses, [TrayStatus.idle]);

    desktop.choose(TrayCommand.startStop);
    await tester.pumpAndSettle();
    expect(recorder.startCalls, hasLength(1));
    expect(desktop.miniCalls, [true]);
    expect(desktop.trayStatuses.last, TrayStatus.recording);
    expect(find.byTooltip('Open RecLite'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    desktop.choose(TrayCommand.pauseResume);
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 1);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(desktop.trayStatuses.last, TrayStatus.paused);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(recorder.resumeCalls, 1);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(desktop.miniCalls, [true, false]);
    expect(desktop.trayStatuses.last, TrayStatus.idle);
    expect(find.text('Recording saved'), findsOneWidget);
  });

  testWidgets('the mini bar can be opened to the full window', (tester) async {
    settings.miniBarWhileRecording = true;
    await pumpApp(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);

    desktop.choose(TrayCommand.showWindow);
    await tester.pumpAndSettle();
    expect(desktop.miniCalls, [true, false]);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('REC'), findsOneWidget, reason: 'still recording');
  });

  testWidgets('asks for screen permission when missing', (tester) async {
    recorder.permission = false;
    await pumpApp(tester);

    expect(find.text('Allow screen recording'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start Recording'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('records a dragged area', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Area'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    expect(recorder.startCalls.single.area, testArea);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recording'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsNothing);
  });

  testWidgets('records a chosen app window', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    expect(find.text('Record a window'), findsOneWidget);
    expect(find.text('chrome · 1600 × 900'), findsOneWidget);

    await tester.tap(find.text('Quarterly review - Slides'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quarterly review - Slides — chrome'),
      findsOneWidget,
      reason: 'the chosen window is shown',
    );

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    final config = recorder.startCalls.single;
    expect(config.windowId, testWindow.id);
    expect(config.area, isNull);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('Quarterly review - Slides — chrome'), findsNothing);
  });

  testWidgets('says so when there is no window to record', (tester) async {
    recorder.windows = const [];
    await pumpApp(tester);

    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No windows to record'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Start Recording'), findsOneWidget);
  });

  testWidgets('fits the minimum window size with an area selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Area'));
    await tester.pumpAndSettle();
    expect(find.text('1280 × 720'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio toggles reach the recording and meters move', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('System sound'), findsOneWidget);

    await tester.tap(find.byType(Switch).last); // microphone
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    final config = recorder.startCalls.single;
    expect(config.captureSystemAudio, isTrue);
    expect(config.captureMicrophone, isTrue);

    recorder.emitLevels(const AudioLevels(system: 0.5, microphone: 0.95));
    await tester.pumpAndSettle();
    final meters = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((m) => m.value)
        .toList();
    expect(meters, containsAll(<double>[0.5, 0.95]));

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.every((s) => s.onChanged == null), isTrue);
  });

  testWidgets('blocked microphone stays off and offers Settings', (
    tester,
  ) async {
    recorder.microphonePermission = false;
    await pumpApp(tester);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
    expect(find.text('Microphone access is off.'), findsOneWidget);
  });

  testWidgets('pause, resume and a multi-part result', (tester) async {
    recorder.stopResult = testMultiPartResult;
    await pumpApp(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(recorder.pauseCalls, 1);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    recorder.emitStatus(testStatus(42, phase: RecordingPhase.paused));
    await tester.pumpAndSettle();
    expect(find.text('00:42'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(recorder.resumeCalls, 1);
    expect(find.text('REC'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('20:00 · 900 MB · 2 parts'), findsOneWidget);
    expect(find.text('RecLite_2026-11-19_10-00-00'), findsOneWidget);
  });

  testWidgets('shows the recovery banner after an interrupted recording', (
    tester,
  ) async {
    recorder.recoverable = const [testRecovered];
    await pumpApp(tester);

    expect(find.text('RecLite recovered a recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('RecLite recovered a recording'), findsNothing);
  });

  testWidgets('recording bar fits the minimum window size', (tester) async {
    tester.view.physicalSize = const Size(760, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Recording'));
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pause'));
    expect(find.text('Pause'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
