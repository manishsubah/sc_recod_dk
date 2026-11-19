import 'package:get_it/get_it.dart';
import 'package:reclite/features/recording/data/repositories/engine_repository_impl.dart';
import 'package:reclite/features/recording/data/repositories/recorder_repository_impl.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_levels_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite_engine/reclite_engine.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt
    ..registerLazySingleton<RecliteEngine>(RecliteEngine.new)
    ..registerLazySingleton<EngineRepository>(
      () => EngineRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerLazySingleton<RecorderRepository>(
      () => RecorderRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerFactory<ReadinessCubit>(
      () => ReadinessCubit(getIt<EngineRepository>()),
    )
    ..registerFactory<SourcesCubit>(
      () => SourcesCubit(getIt<RecorderRepository>()),
    )
    ..registerFactory<AudioCubit>(() => AudioCubit(getIt<RecorderRepository>()))
    ..registerFactory<AudioLevelsCubit>(
      () => AudioLevelsCubit(getIt<RecorderRepository>()),
    )
    ..registerFactory<RecordingBloc>(
      () => RecordingBloc(getIt<RecorderRepository>()),
    );
}
