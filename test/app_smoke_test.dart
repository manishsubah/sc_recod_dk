import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reclite/app/app.dart';
import 'package:reclite/app/di.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/readiness_cubit.dart';

import 'fixtures.dart';

class _FakeEngineRepository implements EngineRepository {
  @override
  Future<EngineInfo> getEngineInfo() async => testEngineInfo;

  @override
  Future<StorageInfo> getStorageInfo(String folder) async =>
      StorageInfo(path: folder, freeBytes: 48e9 ~/ 1, totalBytes: 500e9 ~/ 1);
}

void main() {
  setUp(() {
    getIt.registerFactory<ReadinessCubit>(
      () => ReadinessCubit(_FakeEngineRepository(), outputFolder: '/rec'),
    );
  });

  tearDown(getIt.reset);

  testWidgets('shows readiness and navigates between sections', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RecLiteApp());
    await tester.pumpAndSettle();

    expect(find.text('Ready to Record'), findsOneWidget);
    expect(find.text('macOS 15.1.0'), findsOneWidget);
    expect(find.text('H.264 · HEVC'), findsOneWidget);
    expect(find.text('48.0 GB · about 40 h'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No recordings yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings are on the way'), findsOneWidget);
  });
}
