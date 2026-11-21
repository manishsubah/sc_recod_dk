import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  factory Failure.fromPlatformException(PlatformException e) =>
      switch (e.code) {
        'invalid_path' => const StorageFailure(
          'The selected folder does not exist.',
        ),
        'disk_query_failed' => const StorageFailure(
          'Could not read free disk space.',
        ),
        'permission_denied' => const PermissionFailure(
          'RecLite needs screen recording permission.',
        ),
        'microphone_permission_denied' => const PermissionFailure(
          'RecLite needs microphone permission. Turn it on in System Settings, '
          'or record without the microphone.',
        ),
        'disk_full' => const StorageFailure(
          'The disk is almost full. Free some space or choose another folder.',
        ),
        'display_not_found' => const EngineFailure(
          'The selected display is no longer connected. Pick another one.',
        ),
        'already_recording' => const EngineFailure(
          'A recording is already running.',
        ),
        'not_recording' => const EngineFailure('No recording is running.'),
        'window_not_found' => const EngineFailure(
          'The selected window was closed or minimized. Pick it again.',
        ),
        'invalid_area' => const EngineFailure(
          'The selected area is outside the screen or too small. '
          'Select it again.',
        ),
        'unsupported' => const EngineFailure(
          'Recording is not available on this system yet.',
        ),
        'capture_failed' => EngineFailure('Screen capture failed${_detail(e)}'),
        'open_failed' => const StorageFailure(
          'No app on this computer can play this file.',
        ),
        'trash_failed' => const StorageFailure(
          'The recording could not be removed. '
          'Close any app that is playing it and try again.',
        ),
        'writer_failed' => StorageFailure(
          'The video file could not be saved${_detail(e)}',
        ),
        _ => EngineFailure(e.message ?? 'Unexpected engine error (${e.code}).'),
      };

  final String message;

  static String _detail(PlatformException e) =>
      e.message == null ? '.' : ': ${e.message}';

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

final class EngineFailure extends Failure {
  const EngineFailure(super.message);
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

final class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
