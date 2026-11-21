import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/features/shortcuts/domain/entities/key_combo.dart';
import 'package:reclite/features/shortcuts/domain/repositories/shortcuts_repository.dart';
import 'package:reclite/features/shortcuts/presentation/bloc/shortcuts_cubit.dart';

class MockShortcutsRepository extends Mock implements ShortcutsRepository {}

void main() {
  late MockShortcutsRepository repo;

  setUp(() {
    repo = MockShortcutsRepository();
    when(() => repo.enabled).thenReturn(true);
    when(() => repo.register(any())).thenAnswer((_) async => const {});
    when(() => repo.setEnabled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  final defaults = KeyCombo.defaults();

  blocTest<ShortcutsCubit, ShortcutsState>(
    'registers the default shortcuts at launch',
    build: () => ShortcutsCubit(repo),
    act: (c) => c.start(),
    expect: () => [ShortcutsState(enabled: true, combos: defaults)],
    verify: (_) => verify(() => repo.register(defaults)).called(1),
  );

  blocTest<ShortcutsCubit, ShortcutsState>(
    'reports a shortcut that another app already uses',
    setUp: () =>
        when(() => repo.register(any()))
            .thenAnswer((_) async => {ShortcutAction.pauseResume}),
    build: () => ShortcutsCubit(repo),
    act: (c) => c.start(),
    expect: () => [
      ShortcutsState(
        enabled: true,
        combos: defaults,
        unavailable: const {ShortcutAction.pauseResume},
      ),
    ],
  );

  blocTest<ShortcutsCubit, ShortcutsState>(
    'turning shortcuts off releases them and remembers the choice',
    build: () => ShortcutsCubit(repo),
    act: (c) => c.setEnabled(enabled: false),
    expect: () => [ShortcutsState(enabled: false, combos: defaults)],
    verify: (_) {
      verify(() => repo.setEnabled(enabled: false)).called(1);
      verify(() => repo.register(const {})).called(1);
    },
  );

  blocTest<ShortcutsCubit, ShortcutsState>(
    'stays off at launch when the user turned them off',
    setUp: () => when(() => repo.enabled).thenReturn(false),
    build: () => ShortcutsCubit(repo),
    act: (c) => c.start(),
    expect: () => [ShortcutsState(enabled: false, combos: defaults)],
    verify: (_) => verify(() => repo.register(const {})).called(1),
  );
}
