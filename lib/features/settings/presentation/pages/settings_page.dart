import 'package:flutter/material.dart';

import '../../../../core/widgets/coming_soon.dart';
import '../../../../core/widgets/page_scaffold.dart';

/// Settings (docs/PLAN.md §21.4). Built in Phase 3.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Settings',
      child: ComingSoon(
        icon: Icons.tune,
        title: 'Settings are on the way',
        description:
            'Save folder, quality, split length and keyboard shortcuts will be '
            'configurable here.',
      ),
    );
  }
}
