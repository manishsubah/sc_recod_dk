import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/features/shortcuts/data/repositories/shortcuts_repository_impl.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite_engine/reclite_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRecliteEngine extends Mock implements RecliteEngine {}

void main() {
  late MockRecliteEngine engine;
  late StreamController<int> presses;
  late ShortcutsRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(<EngineShortcut>[]));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    engine = MockRecliteEngine();
    presses = StreamController<int>.broadcast();
    when(() => engine.shortcutPresses).thenAnswer((_) => presses.stream);
    repo = ShortcutsRepositoryImpl(
      engine,
      await SharedPreferences.getInstance(),
    );
  });

  tearDown(() => presses.close());

  test('maps engine indexes back to actions', () async {
    when(() => engine.setGlobalShortcuts(any())).thenAnswer((_) async => [1]);

    final unavailable = await repo.register(KeyCombo.defaults());

    expect(unavailable, {ShortcutAction.pauseResume});
    final sent =
        verify(() => engine.setGlobalShortcuts(captureAny())).captured.single
            as List<EngineShortcut>;
    expect(sent.map((s) => (s.key, s.control, s.alt, s.shift, s.meta)), [
      ('R', true, true, false, false),
      ('P', true, true, false, false),
    ]);

    final got = repo.pressed.first;
    presses.add(0);
    expect(await got, ShortcutAction.startStop);
  });

  test('ignores presses after shortcuts are turned off', () async {
    when(() => engine.setGlobalShortcuts(any())).thenAnswer((_) async => []);
    await repo.register(KeyCombo.defaults());
    await repo.register(const {});

    final got = <ShortcutAction>[];
    final sub = repo.pressed.listen(got.add);
    presses.add(0);
    await pumpEventQueue();
    await sub.cancel();
    expect(got, isEmpty);
  });

  test('an engine error marks every shortcut unavailable', () async {
    when(() => engine.setGlobalShortcuts(any()))
        .thenThrow(PlatformException(code: 'unsupported'));

    expect(await repo.register(KeyCombo.defaults()), {
      ShortcutAction.startStop,
      ShortcutAction.pauseResume,
    });
  });

  test('remembers whether shortcuts are on', () async {
    expect(repo.enabled, isTrue);
    await repo.setEnabled(enabled: false);
    expect(repo.enabled, isFalse);
  });
}
