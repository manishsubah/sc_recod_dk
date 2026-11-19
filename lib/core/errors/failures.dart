import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  factory Failure.fromPlatformException(
    PlatformException e,
  ) => switch (e.code) {
    'invalid_path' => StorageFailure('The selected folder does not exist.'),
    'disk_query_failed' => StorageFailure('Could not read free disk space.'),
    'permission_denied' => PermissionFailure(e.message ?? 'Permission denied.'),
    _ => EngineFailure(e.message ?? 'Unexpected engine error (${e.code}).'),
  };

  final String message;

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
