import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/features/desktop/domain/entities/tray.dart';
import 'package:reclite/features/desktop/domain/repositories/desktop_repository.dart';
import 'package:reclite/features/desktop/presentation/bloc/window_mode_cubit.dart';

class MockDesktopRepository extends Mock implements DesktopRepository {}

void main() {
  late MockDesktopRepository repo;

  setUpAll(() => registerFallbackValue(TrayStatus.idle));

  setUp(() {
    repo = MockDesktopRepository();
    when(() => repo.setMiniWindow(mini: any(named: 'mini')))
        .thenAnswer((_) async {});
    when(() => repo.setTrayStatus(any())).thenAnswer((_) async {});
  });

  blocTest<WindowModeCubit, WindowMode>(
    'switches to the mini bar and back once each',
    build: () => WindowModeCubit(repo),
    act: (c) async {
      await c.showMini();
      await c.showMini();
      await c.showFull();
      await c.showFull();
    },
    expect: () => [WindowMode.mini, WindowMode.full],
    verify: (_) {
      verify(() => repo.setMiniWindow(mini: true)).called(1);
      verify(() => repo.setMiniWindow(mini: false)).called(1);
    },
  );

  blocTest<WindowModeCubit, WindowMode>(
    'sends the tray status only when it changes',
    build: () => WindowModeCubit(repo),
    act: (c) async {
      await c.showTrayStatus(TrayStatus.idle);
      await c.showTrayStatus(TrayStatus.recording);
      await c.showTrayStatus(TrayStatus.recording);
    },
    expect: () => <WindowMode>[],
    verify: (_) {
      verify(() => repo.setTrayStatus(TrayStatus.idle)).called(1);
      verify(() => repo.setTrayStatus(TrayStatus.recording)).called(1);
    },
  );
}
