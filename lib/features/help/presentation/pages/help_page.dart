import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/core/constants/app_info.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';
import 'package:reclite/features/help/presentation/bloc/help_cubit.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HelpCubit, HelpState>(
      listenWhen: (_, s) => s.error != null,
      listener: (context, state) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!))),
      child: const PageScaffold(
        title: 'Help',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AboutCard(),
            SizedBox(height: AppSpacing.md),
            _ContactCard(),
            SizedBox(height: AppSpacing.md),
            _GuideCard(),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  static const _versionLine =
      'Version ${AppInfo.version} (build ${AppInfo.build})';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              AppInfo.iconAsset,
              width: AppSize.aboutIcon,
              height: AppSize.aboutIcon,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppInfo.name, style: theme.textTheme.headlineSmall),
                  Text(_versionLine, style: muted),
                  const SizedBox(height: AppSpacing.xs),
                  Text(AppInfo.copyright, style: muted),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      OutlinedButton(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: AppInfo.name,
                          applicationVersion: _versionLine,
                          applicationIcon: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Image.asset(
                              AppInfo.iconAsset,
                              width: AppSize.aboutIcon,
                              height: AppSize.aboutIcon,
                            ),
                          ),
                          applicationLegalese: AppInfo.copyright,
                        ),
                        child: const Text('Open-source licenses'),
                      ),
                      TextButton.icon(
                        onPressed: () => _copyDetails(context),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy version details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyDetails(BuildContext context) async {
    final details = context.read<HelpCubit>().versionDetails;
    await Clipboard.setData(ClipboardData(text: details));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied: $details')));
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HelpCubit>();
    final hasEmail = AppInfo.supportEmail.isNotEmpty;
    final hasWebsite = AppInfo.website.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get help', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            if (!hasEmail && !hasWebsite)
              Text(
                'Support contact details will be added in a future update.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (hasEmail)
                    FilledButton.tonalIcon(
                      onPressed: cubit.emailSupport,
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Email support'),
                    ),
                  if (hasWebsite)
                    OutlinedButton.icon(
                      onPressed: cubit.openWebsite,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Visit website'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  static String get _startStop => Platform.isMacOS ? '⌃⌥R' : 'Ctrl+Alt+R';
  static String get _pause => Platform.isMacOS ? '⌃⌥P' : 'Ctrl+Alt+P';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [
      (
        'Start and stop',
        'Click Start Recording, or press $_startStop from any app. '
            '$_pause pauses and resumes. Turn the keys off in Settings.',
      ),
      (
        'Record one window or part of the screen',
        'On the Record page, choose Window or Area before you start.',
      ),
      (
        'Where recordings are saved',
        'As MP4 files in the folder set in Settings. History lists them '
            'with Play and Show in folder.',
      ),
      (
        'Why a recording has several files',
        'Long recordings are saved in parts (Settings → Split every), so a '
            'crash or a full disk never costs more than the last part.',
      ),
      (
        'After a crash or power cut',
        'Open RecLite again. It repairs the unfinished recording and keeps '
            'everything that was saved.',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick guide', style: theme.textTheme.titleMedium),
            for (final (question, answer) in entries) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                question,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                answer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
