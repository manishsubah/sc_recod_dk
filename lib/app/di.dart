import 'package:get_it/get_it.dart';
import 'package:reclite/features/recording/data/repositories/engine_repository_impl.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite_engine/reclite_engine.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt
    ..registerLazySingleton<RecliteEngine>(RecliteEngine.new)
    ..registerLazySingleton<EngineRepository>(
      () => EngineRepositoryImpl(getIt<RecliteEngine>()),
    )
    ..registerFactory<ReadinessCubit>(
      () => ReadinessCubit(getIt<EngineRepository>()),
    );
}
