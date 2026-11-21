import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/constants/app_info.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/help/domain/repositories/links_repository.dart';
import 'package:reclite/features/help/presentation/bloc/help_cubit.dart';

class MockLinksRepository extends Mock implements LinksRepository {}

void main() {
  late MockLinksRepository links;

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    links = MockLinksRepository();
    when(() => links.systemDescription).thenReturn('Windows 10.0.26200');
    when(() => links.open(any())).thenAnswer((_) async {});
  });

  test('version details name the app, build and system', () {
    expect(
      HelpCubit(links).versionDetails,
      '${AppInfo.name} ${AppInfo.version} (build ${AppInfo.build}) · '
      'Windows 10.0.26200',
    );
  });

  test('support email carries a subject and the version details', () async {
    await HelpCubit(links).emailSupport();

    final link = verify(() => links.open(captureAny())).captured.single as Uri;
    expect(link.scheme, 'mailto');
    expect(link.toString(), contains('subject=RecLite%20help'));
    expect(link.toString(), isNot(contains('+')));
    expect(
      Uri.decodeComponent(link.query),
      contains('RecLite ${AppInfo.version} (build ${AppInfo.build})'),
    );
  });

  blocTest<HelpCubit, HelpState>(
    'shows a link that could not be opened once',
    setUp: () => when(
      () => links.open(any()),
    ).thenThrow(const StorageFailure('No app on this computer can open it.')),
    build: () => HelpCubit(links),
    act: (c) => c.emailSupport(),
    expect: () => [
      const HelpState(error: 'No app on this computer can open it.'),
      const HelpState(),
    ],
  );
}
