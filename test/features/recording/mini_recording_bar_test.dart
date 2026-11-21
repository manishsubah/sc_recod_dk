import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/theme/app_theme.dart';
import 'package:reclite/features/recording/domain/entities/recording_status.dart';
import 'package:reclite/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:reclite/features/recording/presentation/widgets/mini_recording_bar.dart';

import '../../fixtures.dart';

void main() {
  testWidgets('fits the 380 x 56 bar with a long time and part number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 56);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final recorder = FakeRecorderRepository();
    final bloc = RecordingBloc(recorder);
    addTearDown(() async {
      await bloc.close();
      await recorder.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider.value(
          value: bloc,
          child: MiniRecordingBar(onExpand: () {}, onDragStart: () {}),
        ),
      ),
    );
    bloc.add(const RecordingStartRequested(testConfig));
    await tester.pumpAndSettle();
    recorder.emitStatus(
      const RecordingStatus(
        phase: RecordingPhase.paused,
        elapsed: Duration(hours: 12, minutes: 34, seconds: 56),
        segmentIndex: 50,
        bytesWritten: 0,
        droppedFrames: 0,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
  });
}
