import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recording_options.dart';
import 'package:reclite/features/settings/domain/entities/app_theme_mode.dart';
import 'package:reclite/features/settings/domain/repositories/settings_repository.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RecordingOptions());
    registerFallbackValue(AppThemeMode.system);
  });

  late MockSettingsRepository repo;

  const initial = SettingsState(
    outputFolder: '/videos/RecLite',
    defaultOutputFolder: '/videos/RecLite',
  );

  setUp(() {
    repo = MockSettingsRepository();
    when(() => repo.outputFolder).thenReturn('/videos/RecLite');
    when(() => repo.defaultOutputFolder).thenReturn('/videos/RecLite');
    when(() => repo.setOutputFolder(any())).thenAnswer((_) async {});
    when(() => repo.recordingOptions).thenReturn(const RecordingOptions());
    when(() => repo.themeMode).thenReturn(AppThemeMode.system);
    when(() => repo.miniBarWhileRecording).thenReturn(true);
    when(() => repo.setMiniBarWhileRecording(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => repo.setRecordingOptions(any())).thenAnswer((_) async {});
    when(() => repo.setThemeMode(any())).thenAnswer((_) async {});
  });

  test('starts with the saved folder', () {
    expect(SettingsCubit(repo).state, initial);
    expect(SettingsCubit(repo).state.usesDefaultFolder, isTrue);
  });

  blocTest<SettingsCubit, SettingsState>(
    'saves a picked folder',
    setUp: () =>
        when(() => repo.pickFolder(initialDirectory: '/videos/RecLite'))
            .thenAnswer((_) async => '/work/clips'),
    build: () => SettingsCubit(repo),
    act: (c) => c.chooseFolder(),
    expect: () => [
      const SettingsState(
        outputFolder: '/work/clips',
        defaultOutputFolder: '/videos/RecLite',
      ),
    ],
    verify: (_) => verify(() => repo.setOutputFolder('/work/clips')).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'does nothing when the picker is cancelled',
    setUp: () => when(
      () => repo.pickFolder(initialDirectory: any(named: 'initialDirectory')),
    ).thenAnswer((_) async => null),
    build: () => SettingsCubit(repo),
    act: (c) => c.chooseFolder(),
    expect: () => <SettingsState>[],
    verify: (_) => verifyNever(() => repo.setOutputFolder(any())),
  );

  blocTest<SettingsCubit, SettingsState>(
    'shows a folder that cannot be used once, keeps the old one',
    setUp: () {
      when(
        () => repo.pickFolder(initialDirectory: any(named: 'initialDirectory')),
      ).thenAnswer((_) async => '/read-only');
      when(
        () => repo.setOutputFolder('/read-only'),
      ).thenThrow(const StorageFailure('RecLite cannot save to this folder.'));
    },
    build: () => SettingsCubit(repo),
    act: (c) => c.chooseFolder(),
    expect: () => [
      const SettingsState(
        outputFolder: '/videos/RecLite',
        defaultOutputFolder: '/videos/RecLite',
        error: 'RecLite cannot save to this folder.',
      ),
      initial,
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'goes back to the default folder',
    setUp: () => when(() => repo.outputFolder).thenReturn('/work/clips'),
    build: () => SettingsCubit(repo),
    act: (c) => c.useDefaultFolder(),
    expect: () => [initial],
    verify: (_) =>
        verify(() => repo.setOutputFolder('/videos/RecLite')).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'saves recording choices together',
    build: () => SettingsCubit(repo),
    act: (c) async {
      await c.setSegmentMinutes(30);
      await c.setMaxHeight(1080);
      await c.setFramesPerSecond(60);
      await c.setShowCursor(show: false);
    },
    skip: 3,
    expect: () => [
      initial.copyWith(
        options: const RecordingOptions(
          segmentDuration: Duration(minutes: 30),
          maxHeight: 1080,
          framesPerSecond: 60,
          showCursor: false,
        ),
      ),
    ],
    verify: (_) => verify(
      () => repo.setRecordingOptions(
        const RecordingOptions(
          segmentDuration: Duration(minutes: 30),
          maxHeight: 1080,
          framesPerSecond: 60,
          showCursor: false,
        ),
      ),
    ).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'switches the theme',
    build: () => SettingsCubit(repo),
    act: (c) => c.setThemeMode(AppThemeMode.dark),
    expect: () => [initial.copyWith(themeMode: AppThemeMode.dark)],
    verify: (_) => verify(() => repo.setThemeMode(AppThemeMode.dark)).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'turns the mini bar off',
    build: () => SettingsCubit(repo),
    act: (c) => c.setMiniBarWhileRecording(enabled: false),
    expect: () => [initial.copyWith(miniBarWhileRecording: false)],
    verify: (_) =>
        verify(() => repo.setMiniBarWhileRecording(enabled: false)).called(1),
  );
}
