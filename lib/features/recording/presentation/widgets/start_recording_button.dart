import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/bloc/sources_cubit.dart';
import 'package:reclite/features/recording/presentation/recording_start.dart';

/// Top-right action on the Record page.
class StartRecordingButton extends StatelessWidget {
  const StartRecordingButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canRecord = context.select<ReadinessCubit, bool>(
      (c) => switch (c.state) {
        ReadinessLoaded(:final canRecord) => canRecord,
        _ => false,
      },
    );
    final hasSource = context.select<SourcesCubit, bool>(
      (c) => c.state is SourcesLoaded,
    );
    final (busy, starting) = context.select<RecordingBloc, (bool, bool)>(
      (b) => (b.state.isBusy, b.state is RecordingStarting),
    );

    return FilledButton.icon(
      onPressed: canRecord && hasSource && !busy
          ? () {
              final config = currentRecordingConfig(context);
              if (config != null) {
                context.read<RecordingBloc>().add(
                  RecordingStartRequested(config),
                );
              }
            }
          : null,
      icon: starting
          ? const SizedBox.square(
              dimension: AppSize.inlineProgress,
              child: CircularProgressIndicator(
                strokeWidth: AppSize.progressStroke,
              ),
            )
          : const Icon(Icons.fiber_manual_record, color: AppColors.recording),
      label: Text(
        starting
            ? 'Starting…'
            : busy
            ? 'Recording…'
            : 'Start Recording',
      ),
    );
  }
}
