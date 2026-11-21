import 'dart:io';

import 'package:flutter/services.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/help/domain/repositories/links_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

class LinksRepositoryImpl implements LinksRepository {
  LinksRepositoryImpl(this._engine);

  final RecliteEngine _engine;

  @override
  Future<void> open(Uri link) async {
    try {
      await _engine.openUrl(link.toString());
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }

  @override
  String get systemDescription {
    final os = Platform.isWindows
        ? 'Windows'
        : Platform.isMacOS
        ? 'macOS'
        : Platform.operatingSystem;
    final version = Platform.operatingSystemVersion;
    // "Windows 10 Home" style strings already name the OS.
    return version.contains(os) ? version : '$os $version';
  }
}
