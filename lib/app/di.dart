import 'package:get_it/get_it.dart';
import 'package:reclite/features/desktop/data/repositories/desktop_repository_impl.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';
import 'package:reclite/features/history/data/repositories/history_repository_impl.dart';
import 'package:reclite/features/history/domain/repositories/history_repository.dart';
import 'package:reclite/features/history/presentation/bloc/history_cubit.dart';
import 'package:reclite/features/recording/data/repositories/engine_repository_impl.dart';
import 'package:reclite/features/recording/data/repositories/recorder_repository_impl.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:reclite/features/settings/domain/repositories/settings_repository.dart';
import 'package:reclite/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:reclite/features/shortcuts/data/repositories/shortcuts_repository_impl.dart';
import 'package:reclite/features/shortcuts/domain/repositories/shortcuts_repository.dart';
import 'package:reclite/features/shortcuts/presentation/bloc/shortcuts_cubit.dart';
import 'package:reclite_engine/reclite_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

void configureDependencies(SharedPreferences prefs) {
  String folder() => getIt<SettingsRepository>().outputFolder;
  getIt
    ..registerLazySingleton<RecliteEngine>(RecliteEngine.new)
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(prefs),
    )
    ..registerLazySingleton<EngineRepository>(
      () => EngineRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerLazySingleton<RecorderRepository>(
      () => RecorderRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerLazySingleton<ShortcutsRepository>(
      () => ShortcutsRepositoryImpl(getIt<RecliteEngine>(), prefs),
    )
    ..registerLazySingleton<DesktopRepository>(
      () => DesktopRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerLazySingleton<HistoryRepository>(
      () => HistoryRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerFactory<WindowModeCubit>(
      () => WindowModeCubit(getIt<DesktopRepository>()),
    )
    ..registerFactory<ShortcutsCubit>(
      () => ShortcutsCubit(getIt<ShortcutsRepository>()),
    )
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(getIt<SettingsRepository>()),
    )
    ..registerFactory<ReadinessCubit>(
      () => ReadinessCubit(
        getIt<EngineRepository>(),
        outputFolder: folder(),
        options: getIt<SettingsRepository>().recordingOptions,
      ),
    )
    ..registerFactory<SourcesCubit>(
      () => SourcesCubit(getIt<RecorderRepository>()),
    )
    ..registerFactory<AudioCubit>(() => AudioCubit(getIt<RecorderRepository>()))
    ..registerFactory<AudioLevelsCubit>(
      () => AudioLevelsCubit(getIt<RecorderRepository>()),
    )
    ..registerFactory<RecoveryCubit>(
      () => RecoveryCubit(getIt<RecorderRepository>(), outputFolder: folder()),
    )
    ..registerFactory<RecordingBloc>(
      () => RecordingBloc(getIt<RecorderRepository>()),
    )
    ..registerFactory<HistoryCubit>(
      () => HistoryCubit(getIt<HistoryRepository>(), folder()),
    );
}
