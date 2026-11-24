import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/utils/formatters.dart';
import 'package:reclite/core/widgets/info_bar.dart';
import 'package:reclite/features/recording/presentation/bloc/recovery_cubit.dart';

/// "We saved your last recording" after a crash or power loss.
class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecoveryCubit, RecoveryState>(
      builder: (context, state) => switch (state) {
        RecoveryIdle() => const SizedBox.shrink(),
        RecoveryFound(:final recordings) => _Banner(
          count: recordings.length,
          duration: recordings.fold(
            Duration.zero,
            (sum, r) => sum + r.duration,
          ),
          folder: recordings.last.files.first,
        ),
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.count,
    required this.duration,
    required this.folder,
  });

  final int count;
  final Duration duration;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecoveryCubit>();
    final what = count == 1 ? 'a recording' : '$count recordings';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InfoBar(
        severity: InfoBarSeverity.success,
        title: 'RecLite recovered $what',
        message:
            'It was interrupted before it finished. '
            '${formatElapsed(duration)} was saved.',
        actions: [
          TextButton(
            onPressed: () => cubit.reveal(folder),
            child: Text(
              UiLook.current == UiLook.mac ? 'Show in Finder' : 'Show',
            ),
          ),
        ],
        onDismiss: cubit.dismiss,
      ),
    );
  }
}
