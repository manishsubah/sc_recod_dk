import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/constants/recording_defaults.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/recovered_recording.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

part 'recovery_state.dart';

/// On launch, repairs recordings that a crash or power loss left unfinished.
class RecoveryCubit extends Cubit<RecoveryState> {
  RecoveryCubit(this._recorder, {String? outputFolder})
    : _outputFolder = outputFolder ?? RecordingDefaults.outputFolder(),
      super(const RecoveryIdle());

  final RecorderRepository _recorder;
  String _outputFolder;

  Future<void> check({String? folder}) async {
    if (folder != null) _outputFolder = folder;
    try {
      final recovered = await _recorder.recover(_outputFolder);
      if (recovered.isNotEmpty) emit(RecoveryFound(recovered));
    } on Failure {
      // Recovery is best-effort: the files stay on disk and the next launch retries.
    }
  }

  void reveal(String path) => _recorder.reveal(path).ignore();

  void dismiss() => emit(const RecoveryIdle());
}
