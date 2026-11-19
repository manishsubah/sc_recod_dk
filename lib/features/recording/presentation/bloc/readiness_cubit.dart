import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/recording_defaults.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/engine_info.dart';
import '../../domain/entities/storage_info.dart';
import '../../domain/repositories/engine_repository.dart';

part 'readiness_state.dart';

/// Checks whether this machine can record: OS version, hardware encoder,
/// free disk space. Drives the "Ready to Record" card on the home screen.
class ReadinessCubit extends Cubit<ReadinessState> {
  ReadinessCubit(this._engine, {String? outputFolder})
    : _outputFolder = outputFolder ?? RecordingDefaults.outputFolder(),
      super(const ReadinessLoading());

  final EngineRepository _engine;
  final String _outputFolder;

  Future<void> load() async {
    emit(const ReadinessLoading());
    try {
      final (engine, storage) = await (
        _engine.getEngineInfo(),
        _engine.getStorageInfo(_outputFolder),
      ).wait;
      emit(
        ReadinessLoaded(
          engine: engine,
          storage: storage,
          issues: _findIssues(engine, storage),
        ),
      );
    } on ParallelWaitError<
      (EngineInfo?, StorageInfo?),
      (AsyncError?, AsyncError?)
    > catch (e) {
      final error = e.errors.$1?.error ?? e.errors.$2?.error;
      emit(ReadinessFailed(_messageFor(error)));
    } on Object catch (error) {
      // A repository that throws synchronously, before any future exists.
      emit(ReadinessFailed(_messageFor(error)));
    }
  }

  static String _messageFor(Object? error) => error is Failure
      ? error.message
      : 'Could not reach the recording engine.';

  static List<ReadinessIssue> _findIssues(
    EngineInfo engine,
    StorageInfo storage,
  ) {
    return [
      if (!engine.meetsMinimumOs)
        ReadinessIssue.blocking(
          'RecLite needs ${engine.platformName} ${engine.minimumOsVersion} '
          'or later (this Mac/PC has ${engine.osVersion}).',
        ),
      if (storage.freeBytes < RecordingDefaults.minFreeBytesToStart)
        const ReadinessIssue.blocking(
          'Less than 1 GB free in the save folder. Free some space or choose '
          'another folder.',
        ),
      if (!engine.hasHardwareH264Encoder)
        const ReadinessIssue.warning(
          'No hardware video encoder found. Recording will use more CPU.',
        ),
    ];
  }
}
