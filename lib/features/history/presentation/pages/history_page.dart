import 'package:flutter/material.dart';

import '../../../../core/widgets/coming_soon.dart';
import '../../../../core/widgets/page_scaffold.dart';

/// Recording history (docs/PLAN.md §17). Built in Phase 3.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'History',
      child: ComingSoon(
        icon: Icons.video_library_outlined,
        title: 'No recordings yet',
        description:
            'Your recordings will appear here with date, duration, size and '
            'location.',
      ),
    );
  }
}
