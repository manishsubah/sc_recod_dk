import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';
import 'package:reclite/features/recording/presentation/bloc/audio_cubit.dart';

class MockRecorderRepository extends Mock implements RecorderRepository {}

void main() {
  late MockRecorderRepository repo;

  setUp(() {
    repo = MockRecorderRepository();
    when(() => repo.hasMicrophonePermission()).thenAnswer((_) async => false);
    when(() => repo.requestMicrophonePermission())
        .thenAnswer((_) async => true);
  });

  AudioCubit build() => AudioCubit(repo);

  test('defaults: system sound on, microphone off', () {
    expect(build().state, const AudioState());
  });

  blocTest<AudioCubit, AudioState>(
    'system sound can be turned off',
    build: build,
    act: (c) => c.setSystemAudio(false),
    expect: () => [const AudioState(systemAudio: false)],
  );

  blocTest<AudioCubit, AudioState>(
    'microphone asks for permission and turns on when granted',
    build: build,
    act: (c) => c.setMicrophone(true),
    expect: () => [const AudioState(microphone: true)],
    verify: (_) => verify(() => repo.requestMicrophonePermission()).called(1),
  );

  blocTest<AudioCubit, AudioState>(
    'already granted: no prompt',
    setUp: () =>
        when(() => repo.hasMicrophonePermission())
            .thenAnswer((_) async => true),
    build: build,
    act: (c) => c.setMicrophone(true),
    expect: () => [const AudioState(microphone: true)],
    verify: (_) => verifyNever(() => repo.requestMicrophonePermission()),
  );

  blocTest<AudioCubit, AudioState>(
    'refused permission keeps the mic off and flags it',
    setUp: () =>
        when(() => repo.requestMicrophonePermission())
            .thenAnswer((_) async => false),
    build: build,
    act: (c) => c.setMicrophone(true),
    expect: () => [const AudioState(microphoneBlocked: true)],
  );

  blocTest<AudioCubit, AudioState>(
    'engine failure is treated as blocked',
    setUp: () =>
        when(() => repo.hasMicrophonePermission())
            .thenThrow(const PermissionFailure('no')),
    build: build,
    act: (c) => c.setMicrophone(true),
    expect: () => [const AudioState(microphoneBlocked: true)],
  );

  blocTest<AudioCubit, AudioState>(
    'turning the mic off clears the blocked hint',
    build: build,
    seed: () => const AudioState(microphoneBlocked: true),
    act: (c) => c.setMicrophone(false),
    expect: () => [const AudioState()],
  );
}
