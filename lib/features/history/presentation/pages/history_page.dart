import 'package:flutter/material.dart';

import 'package:reclite/core/widgets/coming_soon.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';

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
