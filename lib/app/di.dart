import 'package:get_it/get_it.dart';
import 'package:reclite_engine/reclite_engine.dart';

import '../features/recording/data/repositories/engine_repository_impl.dart';
import '../features/recording/domain/repositories/engine_repository.dart';
import '../features/recording/presentation/bloc/readiness_cubit.dart';

final getIt = GetIt.instance;

/// Registers app services. Called once from `main()`.
void configureDependencies() {
  getIt
    // Native engine (single instance for the app's lifetime).
    ..registerLazySingleton<RecliteEngine>(RecliteEngine.new)
    // Repositories.
    ..registerLazySingleton<EngineRepository>(
      () => EngineRepositoryImpl(getIt<RecliteEngine>()),
    )
    // Blocs / Cubits: new instance per screen.
    ..registerFactory<ReadinessCubit>(
      () => ReadinessCubit(getIt<EngineRepository>()),
    );
}
