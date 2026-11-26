import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/theme/reclite_theme.dart';
import 'package:reclite/core/widgets/page_scaffold.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets('scrolling a long page on ${platform.name} shows one working '
        'scrollbar', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(900, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PageScaffold(
              title: 'Long page',
              child: Column(
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text('Row $i')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Row 3'), const Offset(0, -600));
      await tester.pumpAndSettle();
      // The scrollbar fades out after a pause; that is when it used to fail.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollbar), findsOneWidget);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, greaterThan(0), reason: 'the page scrolled');

      debugDefaultTargetPlatformOverride = null;
    });
  }
}
