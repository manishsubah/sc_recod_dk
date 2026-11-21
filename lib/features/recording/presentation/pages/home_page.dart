import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
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
    return PageScaffold(
      title: 'Record',
      action: const StartRecordingButton(),
      child: BlocBuilder<ReadinessCubit, ReadinessState>(
        builder: (context, state) => switch (state) {
          ReadinessLoading() => const Padding(
            padding: EdgeInsets.all(AppSpacing.huge),
            child: Center(child: CircularProgressIndicator()),
          ),
          ReadinessFailed(:final message) => _FailedView(message: message),
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
        ReadinessHeader(canRecord: state.canRecord, issues: state.issues),
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (_, s) => s is RecordingFinished || s is RecordingFailed,
          listener: (context, _) => context.read<ReadinessCubit>().refresh(),
          child: const _Spaced(child: RecordingControls()),
        ),
        const SizedBox(height: AppSpacing.md),
        if (engine.supportsRecording) ...[
          const SourceCard(),
          const SizedBox(height: AppSpacing.md),
          AudioCard(
            microphoneSupported: engine.supportsMicrophoneViaScreenCapture,
          ),
        ],
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: AppSize.iconXxl,
              color: scheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.read<ReadinessCubit>().load(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds the gap above the recording status only when there is a status to show.
class _Spaced extends StatelessWidget {
  const _Spaced({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final idle = context.select<RecordingBloc, bool>(
      (b) => b.state is RecordingIdle || b.state is RecordingStarting,
    );
    return idle
        ? child
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: child,
          );
  }
}
