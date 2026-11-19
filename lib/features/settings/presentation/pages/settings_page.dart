import 'package:flutter/material.dart';

import 'package:reclite/core/widgets/coming_soon.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';

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
