import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/widgets/empty_state.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/widgets/audio_card.dart';
import 'package:reclite/features/recording/presentation/widgets/readiness_header.dart';
import 'package:reclite/features/recording/presentation/widgets/recording_controls.dart';
import 'package:reclite/features/recording/presentation/widgets/recovery_banner.dart';
import 'package:reclite/features/recording/presentation/widgets/source_card.dart';
import 'package:reclite/features/recording/presentation/widgets/start_recording_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReadinessCubit, ReadinessState>(
      builder: (context, state) => PageScaffold(
        title: 'Record',
        subtitle: switch (state) {
          final ReadinessLoaded loaded => ReadinessLine(
            canRecord: loaded.canRecord,
            storage: loaded.storage,
          ),
          _ => null,
        },
        action: const StartRecordingButton(),
        child: switch (state) {
          ReadinessLoading() => const Padding(
            padding: EdgeInsets.all(AppSpacing.huge),
            child: Center(child: CircularProgressIndicator()),
          ),
          ReadinessFailed(:final message) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'RecLite could not get ready',
            description: message,
            action: OutlinedButton(
              onPressed: () => context.read<ReadinessCubit>().load(),
              child: const Text('Try again'),
            ),
          ),
          final ReadinessLoaded loaded => _LoadedView(state: loaded),
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final ReadinessLoaded state;

  @override
  Widget build(BuildContext context) {
    final engine = state.engine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RecoveryBanner(),
        ReadinessIssues(issues: state.issues),
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (_, s) => s is RecordingFinished || s is RecordingFailed,
          listener: (context, _) => context.read<ReadinessCubit>().refresh(),
          child: RecordingControls(partLength: state.options.segmentDuration),
        ),
        if (engine.supportsRecording) _Inputs(engine: engine),
      ],
    );
  }
}

/// Source and audio panes. While recording, audio comes first so the live
/// meters stay in view on a small window; the locked source drops below.
class _Inputs extends StatelessWidget {
  const _Inputs({required this.engine});

  final EngineInfo engine;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<RecordingBloc, bool>((b) => b.state.isBusy);
    final source = const SourceCard();
    final audio = AudioCard(
      microphoneSupported: engine.supportsMicrophoneViaScreenCapture,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) audio else source,
        const SizedBox(height: AppSpacing.xl),
        if (busy) source else audio,
      ],
    );
  }
}
